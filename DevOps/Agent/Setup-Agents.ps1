[CmdletBinding()]
Param(
    [String]
    [Parameter(Mandatory = $false)]
    $ConfigFile = "config.json"
)

Begin {
    $config = (Get-Content $ConfigFile) -replace '^\s*//.*' | Out-String | ConvertFrom-Json
}

Process {
    .\Setup-AzureDevOpsAgents.ps1 `
        -add `
        -url $config.accounturl `
        -pool $config.pool `
        -agentprefix $config.agentprefix `
        -agents $config.agents `
        -agentsfolder $config.agentsfolder `
        -work $config.workfolder `
        -runasservice `
        -windowslogonaccount $config.windowslogonaccount
}

End {
    $config = $null
}