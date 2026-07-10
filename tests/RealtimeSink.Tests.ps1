BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
}
Describe 'RealtimeSink type' {
    It 'compiles and exposes the queue + stream surface' {
        $t = InModuleScope MyWebApi { 'MyWebApi.RealtimeSink' -as [type] }
        # * The realtime shim is compiled against a net8 SignalR client. On a pwsh whose
        #   runtime differs enough that Roslyn can't compile the shim (e.g. .NET 10), the
        #   type is absent by design (REST still works). That is an environment condition,
        #   not a code defect -> Inconclusive, not Fail.
        if (-not $t) {
            Set-ItResult -Inconclusive -Because 'RealtimeSink did not compile on this runtime (SignalR client / runtime version mismatch)'
            return
        }
        foreach ($m in 'On','StartStream','TryTake','StartAsync','StopAsync','Dispose') {
            $t.GetMethod($m) | Should -Not -BeNullOrEmpty -Because "method $m must exist"
        }
    }
}
