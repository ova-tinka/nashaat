## Use Case Specification — Login with Email and Password

### Use Case Name
Login with Email and Password

### Brief Description
Allows a registered user to log in to the application using their email and password in order to access protected features.

### Primary Actor
Registered User

### Trigger
User submits email and password on the login screen.

---

### Preconditions
1. User account exists in the system.  
2. User has an active internet connection.

---

### Postconditions
1. User is authenticated successfully.  
2. User is redirected to the dashboard or home page.  
3. User gains access to features based on their permissions.

---

### Main Flow

| Step | Actor Action | System Response |
|------|--------------|-----------------|
| 1 | User navigates to the login page. | |
| 2 | | System displays the login screen. |
| 3 | User enters email and password. | |
| 4 | | System checks that inputs are not empty and email format is valid. |
| 5 | User clicks Login. | |
| 6 | | System validates the credentials. |
| 7 | | System checks that the account is active and email is verified. |
| 8 | | System creates an authenticated session. |
| 9 | | System redirects user to dashboard or home page. |

---

### Alternative Flows

**4.a** If email or password is empty  
- System displays required field error.

**4.b** If email format is invalid  
- System displays invalid email message.

**6.a** If email or password is incorrect  
- System displays “Incorrect email or password”.

**7.a** If email is not verified  
- System informs user that email verification is required and offers resend option.

**7.b** If account is inactive or locked  
- System blocks login and displays appropriate message.