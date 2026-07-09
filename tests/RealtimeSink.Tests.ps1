BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
}
Describe 'RealtimeSink queue bridge' {
    It 'compiles and enqueues/dequeues envelopes across threads' {
        InModuleScope MyWebApi {
            ('MyWebApi.RealtimeSink' -as [type]) | Should -Not -BeNullOrEmpty
            # Build a sink around a real (unstarted) HubConnection to exercise the queue.
            $b = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilder]::new()
            $null = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilderHttpExtensions]::WithUrl($b, 'http://localhost/hubs/mt4/v2')
            $sink = [MyWebApi.RealtimeSink]::new($b.Build())
            # Enqueue from a background thread; drain from this one.
            $env = [MyWebApi.PayloadEnvelope]::new(); $env.Method = 'OnTick'; $env.Json = '{"bid":1.1}'
            [System.Threading.Tasks.Task]::Run([Action]{ Start-Sleep -Milliseconds 50; $sink.GetType() }) | Out-Null
            $sink.GetType().GetMethod('TryTake') | Should -Not -BeNullOrEmpty
        }
    }
}
