# Name: Register with Email and Password

## Description
Allows the user to create a new account by entering an email address and password, so the user can access and use the application.

## Primary Actor
User

## Goal
To successfully create a new account and access the application.

## Trigger
The user clicks on **Register** to create a new account.

---

## Preconditions
1. User has an active internet connection.  
2. User is on the registration screen.

---

## Postconditions
1. A new user account is created in the system with **pending email verification** status.  
2. A verification email is sent to the user.  
3. After successful email verification, the user is redirected to the onboarding page.

---

## Main Flow

| Step | Actor Action | System Response |
|------|-------------|-----------------|
| 1 | User enters email | |
| 2 | User leaves email field | System checks if email is empty and if format is correct |
| 3 | User enters password | |
| 4 | User leaves password field | System checks if password is empty and strong enough |
| 5 | User clicks Register | |
| 6 | | System checks all inputs are valid |
| 7 | | System creates a new user account |
| 8 | | System displays “Congrats! User created successfully” |
| 9 | | System sends email verification to the user |
| 10 | User verifies email | |
| 11 | | System redirects user to onboarding page |

---

## Alternate Flows

### 2a – If email is empty
- System displays **“Email is required”**

### 2b – If email format is incorrect
- System displays **“Email format is invalid”**

### 4a – If password is empty
- System displays **“Password is required”**

### 4b – If password is weak
- System displays **“Password is weak”**

### 6a – If email already exists
- System displays **“Email already registered”**

### 6b – If any input is invalid
- System displays the related error message and stops registration

---

## Notes
- User cannot access the application until email is verified.  
- User remains on the registration screen if any error occurs.