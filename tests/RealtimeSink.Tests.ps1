BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
}
Describe 'RealtimeSink type' {
    It 'compiles and exposes the queue + stream surface' {
        InModuleScope MyWebApi {
            $t = 'MyWebApi.RealtimeSink' -as [type]
            $t | Should -Not -BeNullOrEmpty
            foreach ($m in 'On','StartStream','TryTake','StartAsync','StopAsync','Dispose') {
                $t.GetMethod($m) | Should -Not -BeNullOrEmpty -Because "method $m must exist"
            }
        }
    }
}
