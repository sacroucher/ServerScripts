<#
.Synopsis
   Quick way to find status of installed antivirus software installed on Windows clients machines.
.DESCRIPTION
   With this cmdlet you can easily create report of staus of antivirus protection in the Windows environment. 
.OUTPUTS 
    Custom PSObjects containing the following properties: 
     
    ComputerName             : String   - Hostanme 
    SoftwareName             : String   - Name of inststalled antivirus product
    Enabled                  : Boolean  - Protection status
    UpToDate                 : Boolean  - Product databases are up to date

.EXAMPLE
   Get-AVStatus

ComputerName          SoftwareName                          UpToDate         Enabled
------------          ------------                          --------         -------
PC01                  Microsoft Security Essentials         True             True

.EXAMPLE
   Get-AVStatus -Computer PC02,PC03,PC04

ComputerName          SoftwareName                          UpToDate         Enabled
------------          ------------                          --------         -------
PC02                  Microsoft Security Essentials         True             True
PC03                  AVG AntiVirus Free Edition            True             False
PC04                  avast! Antivirus                      False            True
#>
function Get-AVStatus
{
    [CmdletBinding()]
    Param
    (
        # List of hostnames - if omited getting information about local machine
        [Parameter(Mandatory=$false,
                   Position=0)]
        [String[]]$Computer = [System.Environment]::MachineName,
        
        # Credentials - if not specified using curently logged user
        [Parameter(Mandatory=$false,
                   Position=1)]
        [System.Management.Automation.PSCredential]
        $Credentials = [System.Management.Automation.PSCredential]::Empty
    )#END PARAM

    Begin
    {
        $scriptblock = [scriptblock]::Create(
@'

        if((((Get-WmiObject -Class Win32_OperatingSystem).caption) -like "*XP*"))
            {$namespace = "root\SecurityCenter"}
        else
            {$namespace = "root\SecurityCenter2"}
        Get-WmiObject -namespace $namespace -class antivirusproduct
        
'@)
    }#END BEGIN
    Process
    {
        try
        {
            $inv_result = Invoke-Command -ComputerName $computer -ScriptBlock $scriptblock -Credential $credentials -ErrorAction SilentlyContinue
        }#END TRY
        catch 
        {
        }
    }#END PROCESS
    End
    {
        $fin_result = @()
        foreach ($r in $inv_result){
            $avp = New-Object PSObject
            $avp|Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $null
            $avp|Add-Member -MemberType NoteProperty -Name "SoftwareName" -Value $null
            $avp|Add-Member -MemberType NoteProperty -Name "UpToDate" -Value $null
            $avp|Add-Member -MemberType NoteProperty -Name "Enabled" -Value $null
            $avp.ComputerName = $r.PSComputerName
            $avp.SoftwareName = $r.DisplayName
            if(Get-Member -InputObject $r -Name "productUpToDate"){
                $avp.Enabled = $r.onAccessScanningEnabled
                $avp.UpToDate = $r.productUpToDate
            } #END IF
            else{
                if (('{0:x6}' -f $r.productState).Substring(4,2) -eq "00") {$avp.UpToDate = $true} else {$avp.UpToDate = $false}
                if (('{0:x6}' -f $r.productState).Substring(2,2) -lt 10) {$avp.Enabled = $false} else {$avp.Enabled = $true}
            }#END ELSE
            $fin_result += $avp 
        }#END FOREACH
        $fin_result
    }#END END
}#END FUNCTION