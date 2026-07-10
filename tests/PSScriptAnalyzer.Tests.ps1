Describe 'PSScriptAnalyzer' {
    It 'reports no Error/Warning issues under the module' {
        $settings = "$PSScriptRoot/../PSScriptAnalyzerSettings.psd1"
        $issues = Invoke-ScriptAnalyzer -Path "$PSScriptRoot/../src/MyWebApi" -Recurse -Settings $settings
        $issues | Should -BeNullOrEmpty
    }
}
