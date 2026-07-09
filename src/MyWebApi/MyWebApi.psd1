@{
    RootModule        = 'MyWebApi.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b7e2c1a4-9f3d-4c8e-8a2b-3d5f6e7a8b9c'
    Author            = 'CPlugin'
    CompanyName       = 'CPlugin'
    Copyright         = '(c) 2026 CPlugin. MIT License.'
    Description       = 'PowerShell client for the trading platform management WebAPI (v2): REST + real-time streaming.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('Connect-MyWebApi', 'Disconnect-MyWebApi')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData = @{
        PSData = @{
            Tags         = @('REST', 'API', 'SignalR', 'trading', 'client', 'PSEdition_Core')
            LicenseUri   = 'https://github.com/CPlugin/mywebapi.com-sdk-powershell/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/CPlugin/mywebapi.com-sdk-powershell'
            ReleaseNotes = 'Initial preview release.'
        }
    }
}
