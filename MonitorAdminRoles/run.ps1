Write-Output "PowerShell Timer trigger function executed at:$(get-date)";
 
# Set this $NotifyOnNewAdmins value to true after you've completed the initial upload
$tableName = "roleMonitoring"
$queueName = "adminnotifications"
$connectionString = $env:AzureWebJobsStorage
$keyVaultName = "CeleritasVault"
#$NotifyOnNewAdmins = $false
#$storageAccount = "proxioso365"
#$primaryKey = "PrKuwY/0mkZsSmzezHF3N9wrvc0lIZKqaDkD4cymsqJVecwk6ZPG7TAQRmAN2Fr+jt5lptG/PHFuDuQ/+CYLDQ=="
$FunctionName = "MonitorAdminRoles"
$username = "o365tasks@prxcsp.com"

# Code to retreive with Managed Service Identity
# MSI Variables via Function Application Settings Variables
# Endpoint and Password
$endpoint = $env:MSI_ENDPOINT
$secret = $env:MSI_SECRET
# Vault URI to get AuthN Token
$vaultTokenURI = 'https://vault.azure.net&api-version=2017-09-01'
# Our Key Vault Credential that we want to retreive URI
# NOTE: API Ver for this is 2015-06-01
$vaultSecretURI = 'https://celeritasvault.vault.azure.net/secrets/AdminPassSecureString/bb11e2f53cc14ac984e4649cf0bb6b71/?api-version=2015-06-01'
# Create AuthN Header with our Function App Secret
$header = @{'Secret' = $secret}
# Get Key Vault AuthN Token
$authenticationResult = Invoke-RestMethod -Method Get -Headers $header -Uri ($endpoint +'?resource=' +$vaultTokenURI)
# Use Key Vault AuthN Token to create Request Header
$requestHeader = @{ Authorization = "Bearer $($authenticationResult.access_token)" }
# Call the Vault and Retrieve Creds
$creds = Invoke-RestMethod -Method GET -Uri $vaultSecretURI -ContentType 'application/json' -Headers $requestHeader
write-output "Credential ID: " $($creds.id)
write-output "Credential Value: " $($creds.value) 

$pw = $creds.value

$vaultSecretURI = 'https://celeritasvault.vault.azure.net/secrets/AdminPassKey/00518f985c6e4951abb5b9e90a5b79b7/?api-version=2015-06-01'
$creds = Invoke-RestMethod -Method GET -Uri $vaultSecretURI -ContentType 'application/json' -Headers $requestHeader
write-output "Credential ID: " $($creds.id)
write-output "Credential Value: " $($creds.value) 

[Byte[]] $array = $($creds.value)

# Build Credentials
#$keypath = "D:\home\site\wwwroot\$FunctionName\bin\keys\PassEncryptKey.key"
$secpassword = $pw | ConvertTo-SecureString -Key $array
$credential = New-Object System.Management.Automation.PSCredential ($username, $secpassword)
$credential.GetNetworkCredential().Password

# Connect to MSOnline

#Connect-MsolService -Credential $credential
 
<#
$Ctx = New-AzureStorageContext -ConnectionString $connectionString
$Table = Get-AzureStorageTable -Name $tableName -Context $Ctx -ErrorAction Ignore
if ($Table -eq $null) {
    $Table = New-AzureStorageTable -Name $tableName -Context $Ctx 
}
$Queue = Get-AzureStorageQueue -Name $QueueName -Context $Ctx -ErrorAction Ignore
    if ($Queue -eq $null) {
        $Queue = New-AzureStorageQueue -Name $QueueName -Context $Ctx 
}

# Check for existing Admins
$existingAdmins = (Get-AzureStorageTableRowAll -table $Table).RowKey

$customers = Get-MsolPartnerContract -all
$currentAdmins = @()
foreach ($customer in $customers) {
    $roles = Get-MsolRole -tenantID $customer.tenantid
    $admins = @()
    foreach ($role in $roles) {
        $members = $null
        $members = Get-MsolRoleMember -RoleObjectId $role.objectid -TenantId $customer.TenantId  | Where-Object {$_.rolemembertype -contains "User"}
        if ($members) {
            Write-Output "Found $($members.count) $($role.name)s in $($customer.name)"
            foreach ($member in $members) {
                $member | Add-Member Id "$($role.objectid)-$($member.emailaddress)"
                $member | add-member RoleName $role.Name
                $currentAdmins += $member
                $filter = $null
                $filter = $existingAdmins | Where-Object {$_ -contains $member.Id}
                if($filter){
                    Write-Output "$($member.DisplayName) has already been logged as a $($member.RoleName)"
                }else{
                    Write-Output "New Admin Detected: $($member.DisplayName) - $($member.RoleName)"
                    $admins += $member
                }
            } 
        }
    }
    if ($admins) {
        foreach ($admin in $admins) {
 
            $adminHash = @{
                CustomerName = $customer.name
                TenantID     = $customer.TenantId
                RoleName     = $admin.RoleName
                DisplayName  = $admin.DisplayName
                EmailAddress = $admin.emailaddress
                IsLicensed   = $admin.IsLicensed
            }    
            Add-AzureStorageTableRow -rowKey $admin.id -partitionKey "Admin" -table $table -property $adminHash
            if($notifyOnNewAdmins){
                $QueueMessageText = "New $($admin.RoleName) detected: `nCompany Name: $($customer.name) `nDisplay Name: $($admin.displayname) `nEmail Address: $($admin.EmailAddress) `nIs licensed: $($admin.IsLicensed)"
                $QueueMessage = New-Object -TypeName Microsoft.WindowsAzure.Storage.Queue.CloudQueueMessage -ArgumentList $QueueMessageText
                $Queue.CloudQueue.AddMessage($QueueMessage)
            } 
        }        
    }
}
#>
