# SignalR callbacks run on arbitrary threads without a PowerShell runspace. This compiled
# bridge only queues immutable payloads; Receive-* remains the single PowerShell consumer.
if (-not ('MyWebApi.RealtimeSink' -as [type])) {
    $libDir = Join-Path $PSScriptRoot '..' 'lib'
    $signalRRefs = @(
        (Join-Path $libDir 'Microsoft.AspNetCore.SignalR.Client.Core.dll'),
        (Join-Path $libDir 'Microsoft.AspNetCore.SignalR.Client.dll')
    )
    $signalRRefsPresent = $true
    foreach ($ref in $signalRRefs) {
        if (-not (Test-Path $ref)) { $signalRRefsPresent = $false; break }
    }

    if ($signalRRefsPresent) {
        [void][System.Collections.Concurrent.BlockingCollection[object]]
        [void][System.Text.Json.JsonElement]
        [void][System.Threading.Interlocked]
        [void][System.Threading.Volatile]
        $frameworkRefs = @('System.Collections.Concurrent', 'System.Text.Json', 'System.Threading', 'System.Runtime')
        try {
            Add-Type -CompilerOptions '-nowarn:1701,1702' -ReferencedAssemblies ($frameworkRefs + $signalRRefs) -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.SignalR.Client;

namespace MyWebApi
{
    public sealed class RealtimeSink : IDisposable
    {
        private readonly BlockingCollection<object> _queue = new BlockingCollection<object>(1024);
        private readonly CancellationTokenSource _cts = new CancellationTokenSource();
        private readonly ConcurrentBag<Task> _streamTasks = new ConcurrentBag<Task>();
        private Exception _fault;
        private int _stopped;
        private int _disposed;

        public HubConnection Connection { get; }
        public Exception Fault => Volatile.Read(ref _fault);
        public bool HasFault => Fault != null;

        public RealtimeSink(HubConnection connection)
        {
            Connection = connection ?? throw new ArgumentNullException(nameof(connection));
            Connection.Closed += error =>
            {
                if (error != null && !_cts.IsCancellationRequested) RecordFault(error, "connection closed");
                return Task.CompletedTask;
            };
        }

        private void RecordFault(Exception error, string source)
        {
            if (error == null || _cts.IsCancellationRequested) return;
            Interlocked.CompareExchange(ref _fault, new InvalidOperationException(source + ": " + error.Message, error), null);
            try { _queue.TryAdd(new PayloadEnvelope { Method = "__connectionFault", Json = "{}", Error = Fault }, 100); }
            catch (InvalidOperationException) { }
        }

        private void Enqueue(PayloadEnvelope payload)
        {
            try { _queue.TryAdd(payload, 100, _cts.Token); }
            catch (OperationCanceledException) { }
            catch (InvalidOperationException) { }
        }

        public void On(string method)
        {
            Connection.On<JsonElement>(method, arg =>
            {
                if (_cts.IsCancellationRequested) return;
                try { Enqueue(new PayloadEnvelope { Method = method, Json = arg.GetRawText() }); }
                catch (Exception error) { RecordFault(error, "callback " + method); }
            });
        }

        public void StartStream(string method)
        {
            var task = Task.Run(async () =>
            {
                try
                {
                    await foreach (var item in Connection.StreamAsync<JsonElement>(method, _cts.Token))
                    {
                        Enqueue(new PayloadEnvelope { Method = method, Json = item.GetRawText() });
                    }
                }
                catch (OperationCanceledException) when (_cts.IsCancellationRequested) { }
                catch (Exception error) { RecordFault(error, "stream " + method); }
            }, _cts.Token);
            _streamTasks.Add(task);
        }

        public bool TryTake(out object item, int timeoutMs) => _queue.TryTake(out item, timeoutMs, _cts.Token);

        public Task StartAsync() => Connection.StartAsync(_cts.Token);

        public Task StopAsync() => StopAsync(30000);

        public async Task StopAsync(int timeoutMilliseconds)
        {
            if (Interlocked.Exchange(ref _stopped, 1) == 1) return;
            _cts.Cancel();
            Exception failure = null;
            try { await Connection.StopAsync().WaitAsync(TimeSpan.FromMilliseconds(timeoutMilliseconds)); }
            catch (Exception error) { failure = error; RecordFault(error, "connection stop"); }
            try
            {
                var allStreams = Task.WhenAll(_streamTasks);
                await allStreams.WaitAsync(TimeSpan.FromMilliseconds(timeoutMilliseconds));
            }
            catch (Exception error) { failure ??= error; RecordFault(error, "stream stop"); }
            try { await Connection.DisposeAsync().AsTask().WaitAsync(TimeSpan.FromMilliseconds(timeoutMilliseconds)); }
            catch (Exception error) { failure ??= error; RecordFault(error, "connection dispose"); }
            _queue.CompleteAdding();
            if (failure != null) throw failure;
        }

        public void Dispose()
        {
            if (Interlocked.Exchange(ref _disposed, 1) == 1) return;
            _cts.Cancel();
            _queue.CompleteAdding();
            _cts.Dispose();
            _queue.Dispose();
        }
    }

    public sealed class PayloadEnvelope
    {
        public string Method { get; set; } = "";
        public string Json { get; set; } = "";
        public Exception Error { get; set; }
    }
}
'@
        } catch {
            throw "MyWebApi real-time assemblies are incompatible with this PowerShell/.NET runtime: $($_.Exception.Message)"
        }
    }
}
