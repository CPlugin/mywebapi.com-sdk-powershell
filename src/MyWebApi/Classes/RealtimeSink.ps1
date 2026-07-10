# * SignalR .On handlers fire on arbitrary threads where a PowerShell ScriptBlock has
#   no runspace. So the bridge is a COMPILED delegate that only enqueues into a
#   thread-safe BlockingCollection; the PowerShell Receive-* cmdlets drain it. This is
#   the single trick that makes SignalR usable from PowerShell.
if (-not ('MyWebApi.RealtimeSink' -as [type])) {
    # * Add-Type's default reference set (a fixed curated list, not "everything currently
    #   loaded") does not include System.Collections.Concurrent / System.Text.Json, so the C#
    #   below fails with CS0234/CS0246 unless we pass them explicitly. (Task / TimeSpan / object
    #   etc. resolve fine without extra refs -- on .NET Core those live inside
    #   System.Private.CoreLib, which Add-Type always references implicitly.)
    #   Pass these two by SIMPLE NAME, not by full file path: they are already loaded in the
    #   pwsh process (forced above via [void][Type]), so Add-Type resolves the name against the
    #   already-loaded assembly. Passing the resolved -Location path instead was tried and
    #   broke compilation with CS0012 "Object is not referenced" on every basic type -- passing
    #   an already-implicitly-referenced framework assembly's file path a second time makes
    #   Roslyn stop recognizing the implicit corlib reference. Simple names avoid that entirely.
    [void][System.Collections.Concurrent.BlockingCollection[object]]
    [void][System.Text.Json.JsonElement]
    $frameworkRefs = @(
        'System.Collections.Concurrent',
        'System.Text.Json'
    )
    $signalRRefs = @(
        (Join-Path $PSScriptRoot '..' 'lib' 'Microsoft.AspNetCore.SignalR.Client.Core.dll'),
        (Join-Path $PSScriptRoot '..' 'lib' 'Microsoft.AspNetCore.SignalR.Client.dll')
    )
    Add-Type -ReferencedAssemblies ($frameworkRefs + $signalRRefs) -TypeDefinition @'
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
        private readonly BlockingCollection<object> _queue = new BlockingCollection<object>();
        private readonly CancellationTokenSource _cts = new CancellationTokenSource();
        public HubConnection Connection { get; }

        public RealtimeSink(HubConnection connection) { Connection = connection; }

        // Register a server->client callback (OnConnectionStatus, OnTick): enqueue the raw JSON.
        public void On(string method)
        {
            Connection.On<JsonElement>(method, arg =>
            {
                try { _queue.Add(new PayloadEnvelope { Method = method, Json = arg.GetRawText() }); }
                catch { /* queue completed/disposed during shutdown - drop late callback */ }
            });
        }

        // Consume a server-streaming hub method on a background task, funneling items into the queue.
        public void StartStream(string method)
        {
            _ = Task.Run(async () =>
            {
                try
                {
                    await foreach (var item in Connection.StreamAsync<JsonElement>(method, _cts.Token))
                    {
                        try { _queue.Add(new PayloadEnvelope { Method = method, Json = item.GetRawText() }); }
                        catch { break; }
                    }
                }
                catch (OperationCanceledException) { /* normal on disconnect */ }
                catch { /* stream ended / connection closed */ }
            });
        }

        public bool TryTake(out object item, int timeoutMs) => _queue.TryTake(out item, timeoutMs);

        public Task StartAsync() => Connection.StartAsync();

        public async Task StopAsync()
        {
            _cts.Cancel();
            try { await Connection.StopAsync(); } catch { }
            try { await Connection.DisposeAsync(); } catch { }
            _queue.CompleteAdding();
        }

        public void Dispose()
        {
            try { _cts.Cancel(); } catch { }
            _cts.Dispose();
            _queue.Dispose();
        }
    }

    public sealed class PayloadEnvelope
    {
        public string Method { get; set; } = "";
        public string Json { get; set; } = "";
    }
}
'@
}
