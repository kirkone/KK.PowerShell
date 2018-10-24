#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'add')]
param
(
    [switch]
    [Parameter(ParameterSetName = "add", Position = 0, Mandatory = $true)]
    $add,
    [switch]
    [Parameter(ParameterSetName = "remove", Position = 0, Mandatory = $true)]
    $remove,
    [switch]
    [Parameter(ParameterSetName = "add", Mandatory = $false)]
    $deploy,

    [String[]]
    [Parameter(ParameterSetName = "add", Mandatory = $true)]
    [Parameter(ParameterSetName = "remove", Mandatory = $true)]
    $agents = "",
    [String[]]
    [Parameter(ParameterSetName = "add", Mandatory = $false)]
    [Parameter(ParameterSetName = "remove", Mandatory = $false)]
    $agentprefix = "",
    [string]
    [Parameter(ParameterSetName = "add", Mandatory = $false)]
    [Parameter(ParameterSetName = "remove", Mandatory = $false)]
    $agentsfolder = "$PWD",
    [string]
    [Parameter(ParameterSetName = "add", Mandatory = $false)]
    $agentzip = "",
    [string]
    [Parameter(ParameterSetName = "add", Mandatory = $true)]
    [Parameter(ParameterSetName = "remove", Mandatory = $true)]
    $token = "",
    [string]
    [Parameter(ParameterSetName = "add", Mandatory = $true)]
    $url = "",
    [string]
    [Parameter(ParameterSetName = "add", Mandatory = $true)]
    [Parameter(ParameterSetName = "remove", Mandatory = $true)]
    $work = "",
    [switch]
    [Parameter(ParameterSetName = "add", Mandatory = $false)]
    $runasservice
)

DynamicParam {
    $paramDic = new-object System.Management.Automation.RuntimeDefinedParameterDictionary
    
    if ($runasservice) {
        $attrCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute] 
        # Attribute für die Parameter definieren
        $attr = new-object System.Management.Automation.ParameterAttribute
            
        # Zugehörigkeit zum ParameterSet definieren
        $attr.ParameterSetName = "add"
        $attr.Mandatory = $false
        $attrCollection.Add($attr)

        # Parameter definieren
        $dynParam1 = new-object System.Management.Automation.RuntimeDefinedParameter("windowslogonaccount", [String], $attrCollection)
        $dynParam2 = new-object System.Management.Automation.RuntimeDefinedParameter("windowslogonpassword", [String], $attrCollection)
            
        # Parameter zum Dictionary hinzufügen
        $paramDic.Add("windowslogonaccount", $dynParam1)
        $paramDic.Add("windowslogonpassword", $dynParam2)
    }

    if ($add -and -not $deploy) {
        $attrCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute] 
        # Attribute für die Parameter definieren
        $attr = new-object System.Management.Automation.ParameterAttribute
            
        # Zugehörigkeit zum ParameterSet definieren
        $attr.ParameterSetName = "add"
        $attr.Mandatory = $false
        $attrCollection.Add($attr)

        # Parameter definieren
        $poolParam = new-object System.Management.Automation.RuntimeDefinedParameter("pool", [String], $attrCollection)
        $PSBoundParameters["pool"] = "default"
            
        # Parameter zum Dictionary hinzufügen
        $paramDic.Add("pool", $poolParam)
    }

    if ($add -and $deploy) {
        $attrCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute] 
        # Attribute für die Parameter definieren
        $attr = new-object System.Management.Automation.ParameterAttribute
            
        # Zugehörigkeit zum ParameterSet definieren
        $attr.ParameterSetName = "add"
        $attr.Mandatory = $true
        $attrCollection.Add($attr)

        # Parameter definieren
        $projectParam = new-object System.Management.Automation.RuntimeDefinedParameter("project", [String], $attrCollection)
        $groupParam = new-object System.Management.Automation.RuntimeDefinedParameter("group", [String], $attrCollection)
            
        # Parameter zum Dictionary hinzufügen
        $paramDic.Add("project", $projectParam)
        $paramDic.Add("group", $groupParam)
    }

    return $paramDic
}

Begin {
    Write-Verbose "Parameter Values:"
    foreach ($key in $PSBoundParameters.Keys) {
        Write-Verbose ("    $key = $($PSBoundParameters[$key])")
    }

    function Test-IsAdmin {
        ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    }
    
    if ($runasservice -and !(Test-IsAdmin)) {
        # Check if the user is starting the script as administrator
        if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {    
            $arguments = "& '" + $myinvocation.mycommand.definition + "'" 
            Start-Process powershell -Verb runAs -ArgumentList $arguments 
            Break 
        } 
    }

    $windowslogonaccount = $PSBoundParameters.windowslogonaccount
    $windowslogonpassword = $PSBoundParameters.windowslogonpassword
    $pool = $PSBoundParameters.pool
    $project = $PSBoundParameters.project
    $group = $PSBoundParameters.group

    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Please provide 'group' and 'project' when using '-deploy'!"
    }

    if ($add -and [string]::IsNullOrWhiteSpace($agentzip)) {
        Write-Verbose "No agent zip specified, looking for '`$PWD\vsts-agent-win*-x64-*.zip'"
        $zip = Get-ChildItem $PWD\ -name vsts-agent-win*-x64-*.zip
        if (-Not $zip) {
            throw "Agent zip not found!"
        }
        $agentzip = "$PWD\{0}" -f ($zip)
        Write-Verbose "    Found: $agentzip"
    }

    if ($deploy -and ([string]::IsNullOrWhiteSpace($project) -or [string]::IsNullOrWhiteSpace($group))) {
        throw "Please provide 'group' and 'project' when using '-deploy'!"
    }

    if ($runasservice -And -Not [string]::IsNullOrWhiteSpace($windowslogonaccount) -And [string]::IsNullOrWhiteSpace($windowslogonpassword)) {
        $securePassword = Read-Host -Prompt "Please enter password for Service Account" -AsSecureString
        $windowslogonpassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
    }
}

Process {
    Function Add-Agent([string] $agent) {
        $agentname = "{0}$agent" -f ("$agentprefix-","")[[string]::IsNullOrWhiteSpace($agentprefix)]
        $workfolder = "$work$agent"

        if (Test-Path "$agentsfolder\$agentname") {
            Write-Error "Agent folder (""$agentsfolder\$agentname"") allready exists!"
            exit 1
        }

        if (Test-Path "$workfolder") {
            Write-Error "Work folder (""$workfolder"") allready exists!"
            exit 1
        }

        Write-Output "Adding agent ""$agentname""..."

        Write-Output "    Unzip agent..."
    
        Add-Type -Assembly "System.IO.Compression.FileSystem"
        [System.IO.Compression.ZipFile]::ExtractToDirectory($agentzip, "$agentsfolder\$agentname")
        Write-Output "        Done."

        Write-Output "    Setup agent..."

        $addcommand = ""
        if (-not $deploy) {
            $addcommand = "& $agentsfolder\$agentname\config.cmd --unattended --url $url --auth PAT --token $token --pool $pool --agent $agentname --work ""$workfolder"" --replace"
        }
        else {
            $addcommand = "& $agentsfolder\$agentname\config.cmd --unattended --url $url --auth PAT --token $token --agent $agentname --work ""$workfolder"" --replace --deploymentgroup --deploymentgroupname ""$group"" --projectname ""$project"""            
        }
        
        if ($runasservice) {
            Write-Output "        Run as service"
            $addcommand += " --runasservice"
            if (-Not [string]::IsNullOrWhiteSpace($windowslogonaccount)) {
                Write-Output "            Using account: $windowslogonaccount"
                $addcommand += " --windowslogonaccount $windowslogonaccount --windowslogonpassword ""$windowslogonpassword"""
            }
        }

        Write-Verbose ("$addcommand").Replace( "$windowslogonpassword" , "******")

        Invoke-Expression $addcommand

        Write-Output "        Done."
        Write-Output "    Done."
    }

    Function Remove-Agent([string] $agent) {
        $agentname = "{0}$agent" -f ("$agentprefix-","")[[string]::IsNullOrEmpty($agentprefix)]
        $workfolder = "$work$agent"

        if (Test-Path "$agentsfolder\$agentname\config.cmd") {
            Write-Output "Removing Agent ""$agentname""..."
            Invoke-Expression "& $agentsfolder\$agentname\config.cmd remove --unattended --auth PAT --token $token"
            Write-Output "    Done."
        }

        Write-Output "Cleanup..."
        if (Test-Path "$agentsfolder\$agentname") {
            Write-Output "    Agent folder..."
            Remove-Item $agentsfolder\$agentname -Force -Recurse
            Write-Output "        Done."
        }
    
        if (Test-Path "$workfolder") {
            Write-Output "    Work folder..."
            Remove-Item $workfolder -Force -Recurse
            Write-Output "        Done."
        }

        Write-Output "    Done."
    }

    $work = "$($work.TrimEnd('\'))\"
    foreach ($agent in $agents | Select-Object -uniq) {
        if ($add) {
            Add-Agent($agent)
        }
        elseif ($remove) {
            Remove-Agent($agent)
        }
    }
}
