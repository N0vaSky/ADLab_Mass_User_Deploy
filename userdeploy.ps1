# ----- Edit these Variables for your own Use Case ----- #
$PASSWORD_FOR_USERS   = "Password1"
$EMAIL_DOMAIN         = "contoso.com"     # Domain for email addresses
$OU_NAME              = "_USERS"          # Name of the OU to create
$NUM_USERS            = 100               # Number of users to create
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

# Convert password
$password = ConvertTo-SecureString $PASSWORD_FOR_USERS -AsPlainText -Force

# Create OU
try {
    New-ADOrganizationalUnit -Name $OU_NAME -ProtectedFromAccidentalDeletion $false
    Write-Host "Created OU: $OU_NAME" -ForegroundColor Green
} catch {
    Write-Host "OU '$OU_NAME' may already exist or there was an error creating it: $_" -ForegroundColor Yellow
}

# Create users
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
        # Create user account
        New-AdUser -AccountPassword $password `
                   -GivenName $first `
                   -Surname $last `
                   -DisplayName "$first $last" `
                   -Name $username `
                   -SamAccountName $username `
                   -UserPrincipalName "$username@$EMAIL_DOMAIN" `
                   -EmailAddress $emailAddress `
                   -EmployeeID $username `
                   -PasswordNeverExpires $true `
                   -Path "ou=$OU_NAME,$(([ADSI]`"").distinguishedName)" `
                   -Enabled $true
        
        # Set proxy addresses for Exchange/SMTP
        Set-ADUser -Identity $username -Add @{ProxyAddresses = $proxyAddress}
        
        Write-Host "Successfully created user: $username" -ForegroundColor Green
    } catch {
        Write-Host "Error creating user $username: $_" -ForegroundColor Red
    }
}

# Output summary
Write-Host "`nCreated $($USER_FIRST_LAST_LIST.Count) users in OU=$OU_NAME" -ForegroundColor Green
Write-Host "All users have the password: $PASSWORD_FOR_USERS"
Write-Host "Email domain set to: $EMAIL_DOMAIN"
