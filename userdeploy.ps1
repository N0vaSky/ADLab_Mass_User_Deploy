# ----- Edit these Variables for your own Use Case ----- #
$PASSWORD_FOR_USERS   = "Password1"
$PASSWORD_FOR_ADMINS  = "Imanadmin123!"
$EMAIL_DOMAIN         = "contoso.com"     # Domain for email addresses
$OU_NAME              = "_USERS"          # Name of the OU to create
$SUB_OU_NAME          = "M365"            # Name of the sub-OU for Azure sync
$NUM_USERS            = 100               # Number of users to create
$NUM_ADMINS           = 3                 # Number of domain admins to create
# ------------------------------------------------------ #

# Function to generate random names
function Get-RandomName {
    $firstNames = @(
        "James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda", "William", "Elizabeth", 
        "David", "Susan", "Richard", "Jessica", "Joseph", "Sarah", "Thomas", "Karen", "Charles", "Nancy", 
        "Christopher", "Lisa", "Daniel", "Margaret", "Matthew", "Betty", "Anthony", "Sandra", "Mark", "Ashley", 
        "Donald", "Dorothy", "Steven", "Kimberly", "Paul", "Emily", "Andrew", "Donna", "Joshua", "Michelle", 
        "Kenneth", "Carol", "Kevin", "Amanda", "Brian", "Melissa", "George", "Deborah", "Timothy", "Stephanie"
    )
    
    $lastNames = @(
        "Smith", "Johnson", "Williams", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor", 
        "Anderson", "Thomas", "Jackson", "White", "Harris", "Martin", "Thompson", "Garcia", "Martinez", "Robinson", 
        "Clark", "Rodriguez", "Lewis", "Lee", "Walker", "Hall", "Allen", "Young", "Hernandez", "King", 
        "Wright", "Lopez", "Hill", "Scott", "Green", "Adams", "Baker", "Gonzalez", "Nelson", "Carter", 
        "Mitchell", "Perez", "Roberts", "Turner", "Phillips", "Campbell", "Parker", "Evans", "Edwards", "Collins"
    )
    
    $first = Get-Random -InputObject $firstNames
    $last = Get-Random -InputObject $lastNames
    
    return "$first $last"
}

# Generate random user list
$USER_FIRST_LAST_LIST = @()
for ($i = 0; $i -lt $NUM_USERS; $i++) {
    $USER_FIRST_LAST_LIST += Get-RandomName
}

# Make sure we have unique names
$USER_FIRST_LAST_LIST = $USER_FIRST_LAST_LIST | Select-Object -Unique

# If we don't have enough unique names, generate more
while ($USER_FIRST_LAST_LIST.Count -lt $NUM_USERS) {
    $USER_FIRST_LAST_LIST += Get-RandomName
    $USER_FIRST_LAST_LIST = $USER_FIRST_LAST_LIST | Select-Object -Unique
}

# Trim to desired number
$USER_FIRST_LAST_LIST = $USER_FIRST_LAST_LIST | Select-Object -First $NUM_USERS

# Generate admin user list (separate from regular users)
$ADMIN_FIRST_LAST_LIST = @()
for ($i = 0; $i -lt $NUM_ADMINS; $i++) {
    $ADMIN_FIRST_LAST_LIST += Get-RandomName
}

# Make sure admin names are unique
$ADMIN_FIRST_LAST_LIST = $ADMIN_FIRST_LAST_LIST | Select-Object -Unique

# Ensure there's no overlap between regular users and admins
$ADMIN_FIRST_LAST_LIST = $ADMIN_FIRST_LAST_LIST | Where-Object { $USER_FIRST_LAST_LIST -notcontains $_ }

# If we don't have enough unique admin names, generate more
while ($ADMIN_FIRST_LAST_LIST.Count -lt $NUM_ADMINS) {
    $newName = Get-RandomName
    if ($USER_FIRST_LAST_LIST -notcontains $newName -and $ADMIN_FIRST_LAST_LIST -notcontains $newName) {
        $ADMIN_FIRST_LAST_LIST += $newName
    }
}

# Trim admin list to desired number
$ADMIN_FIRST_LAST_LIST = $ADMIN_FIRST_LAST_LIST | Select-Object -First $NUM_ADMINS

# Convert passwords
$userPassword = ConvertTo-SecureString $PASSWORD_FOR_USERS -AsPlainText -Force
$adminPassword = ConvertTo-SecureString $PASSWORD_FOR_ADMINS -AsPlainText -Force

# Create main OU
try {
    New-ADOrganizationalUnit -Name $OU_NAME -ProtectedFromAccidentalDeletion $false
    Write-Host "Created OU: $OU_NAME" -ForegroundColor Green
} catch {
    Write-Host "OU '$OU_NAME' may already exist or there was an error creating it: $_" -ForegroundColor Yellow
}

# Create sub-OU for M365/Azure sync
try {
    New-ADOrganizationalUnit -Name $SUB_OU_NAME -Path "OU=$OU_NAME,$(([ADSI]`"").distinguishedName)" -ProtectedFromAccidentalDeletion $false
    Write-Host "Created sub-OU: $SUB_OU_NAME under $OU_NAME" -ForegroundColor Green
} catch {
    Write-Host "Sub-OU '$SUB_OU_NAME' may already exist or there was an error creating it: $_" -ForegroundColor Yellow
}

# Create regular users in the M365 sub-OU
foreach ($n in $USER_FIRST_LAST_LIST) {
    $first = $n.Split(" ")[0]
    $last = $n.Split(" ")[1]
    
    # Create username (first initial + last name, all lowercase)
    $username = "$($first.Substring(0,1))$($last)".ToLower()
    
    # Create email addresses
    $emailAddress = "$username@$EMAIL_DOMAIN"
    $proxyAddress = "SMTP:$emailAddress"
    
    # Display progress
    Write-Host "Creating user: $($username) with email $emailAddress" -BackgroundColor Black -ForegroundColor Cyan
    
    try {
        # Create user account in the M365 sub-OU
        New-AdUser -AccountPassword $userPassword `
                   -GivenName $first `
                   -Surname $last `
                   -DisplayName "$first $last" `
                   -Name $username `
                   -SamAccountName $username `
                   -UserPrincipalName "$username@$EMAIL_DOMAIN" `
                   -EmailAddress $emailAddress `
                   -EmployeeID $username `
                   -PasswordNeverExpires $true `
                   -Path "ou=$SUB_OU_NAME,ou=$OU_NAME,$(([ADSI]`"").distinguishedName)" `
                   -Enabled $true
        
        # Set proxy addresses for Exchange/SMTP
        Set-ADUser -Identity $username -Add @{ProxyAddresses = $proxyAddress}
        
        Write-Host "Successfully created user: $username" -ForegroundColor Green
    } catch {
        Write-Host "Error creating user $username`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Create Domain Admin users
foreach ($n in $ADMIN_FIRST_LAST_LIST) {
    $first = $n.Split(" ")[0]
    $last = $n.Split(" ")[1]
    
    # Create admin username with "admin_" prefix 
    $username = "admin_$($first.Substring(0,1))$($last)".ToLower()
    
    # Create email addresses
    $emailAddress = "$username@$EMAIL_DOMAIN"
    $proxyAddress = "SMTP:$emailAddress"
    
    # Display progress
    Write-Host "Creating DOMAIN ADMIN: $($username)" -BackgroundColor Black -ForegroundColor Red
    
    try {
        # Create admin account directly in Users container
        New-AdUser -AccountPassword $adminPassword `
                   -GivenName $first `
                   -Surname $last `
                   -DisplayName "[ADMIN] $first $last" `
                   -Name $username `
                   -SamAccountName $username `
                   -UserPrincipalName "$username@$EMAIL_DOMAIN" `
                   -EmailAddress $emailAddress `
                   -PasswordNeverExpires $true `
                   -Path "CN=Users,$(([ADSI]`"").distinguishedName)" `
                   -Enabled $true
        
        # Set proxy addresses for Exchange/SMTP
        Set-ADUser -Identity $username -Add @{ProxyAddresses = $proxyAddress}
        
        # Add to Domain Admins group
        Add-ADGroupMember -Identity "Domain Admins" -Members $username
        
        Write-Host "Successfully created Domain Admin: $username" -ForegroundColor Yellow
    } catch {
        Write-Host "Error creating Domain Admin $username`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Output summary
Write-Host "`n====================== SUMMARY ======================" -ForegroundColor Green
Write-Host "Created $($USER_FIRST_LAST_LIST.Count) regular users in OU=$SUB_OU_NAME,OU=$OU_NAME" -ForegroundColor Green
Write-Host "Created $($ADMIN_FIRST_LAST_LIST.Count) Domain Admins in CN=Users" -ForegroundColor Yellow
Write-Host "Regular users password: $PASSWORD_FOR_USERS" -ForegroundColor Green
Write-Host "Admin users password: $PASSWORD_FOR_ADMINS" -ForegroundColor Yellow
Write-Host "Email domain set to: $EMAIL_DOMAIN" -ForegroundColor Cyan
Write-Host "M365/Azure sync target OU: OU=$SUB_OU_NAME,OU=$OU_NAME,$(([ADSI]`"").distinguishedName)" -ForegroundColor Cyan
Write-Host "===================== COMPLETED =====================" -ForegroundColor Green
