Write-Output "PowerShell Timer trigger function executed at:$(get-date)";
 
# Set this $NotifyOnNewAdmins value to true after you've completed the initial upload
$NotifyOnNewAdmins = $false
$storageAccount = "proxioso365"
$primaryKey = "PrKuwY/0mkZsSmzezHF3N9wrvc0lIZKqaDkD4cymsqJVecwk6ZPG7TAQRmAN2Fr+jt5lptG/PHFuDuQ/+CYLDQ=="
$tableName = "roleMonitoring"
$queueName = "adminnotifications"
$FunctionName = "MonitorAdminRoles"
$username = $Env:user
$pw = $Env:password
# Build Credentials
$keypath = "D:\home\site\wwwroot\$FunctionName\bin\keys\PassEncryptKey.key"
$secpassword = $pw | ConvertTo-SecureString -Key (Get-Content $keypath)
$credential = New-Object System.Management.Automation.PSCredential ($username, $secpassword)
   
# Connect to MSOnline
Connect-MsolService -Credential $credential
 
 
$Ctx = New-AzureStorageContext $storageAccount -StorageAccountKey $primaryKey
$Table = Get-AzureStorageTable -Name $tableName -Context $ctx -ErrorAction Ignore
 
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