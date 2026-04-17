# Nashaat - High-Level System Architecture

```mermaid
graph TB
    subgraph User["👤 User"]
        mobile["Mobile Device<br/>(iOS / Android)"]
    end

    subgraph Presentation["Presentation Layer"]
        direction TB
        auth_screens["Auth Screens<br/>(Login, Register, OTP)"]
        blocking_screens["Blocking Screens<br/>(Rules, App Picker)"]
        dashboard_screens["Dashboard Screens"]
        log_screens["Log Activity Screens"]
        onboarding_screens["Onboarding Screens"]
        subscription_screens["Subscription Screens"]

        auth_vm["Auth ViewModel"]
        blocking_vm["Blocking ViewModel"]
        dashboard_vm["Dashboard ViewModel"]
        log_vm["Log Activity ViewModel"]

        coordinator["AppCoordinator + AppRouter<br/>(Navigation)"]
        shared["Shared: Theme (Material 3) + Logger"]
    end

    subgraph Domain["Domain Layer (core/)"]
        direction TB
        entities["Entities<br/>(Profile, Exercise, WorkoutPlan,<br/>WorkoutLog, BlockingRule,<br/>Friendship, Leaderboard, etc.)"]
        repo_interfaces["Repository Interfaces (14)<br/>(AuthRepo, BlockingRepo, ProfileRepo,<br/>WorkoutPlanRepo, WorkoutLogRepo, etc.)"]
        enums["Domain Enums (10)<br/>(ItemType, FriendshipStatus,<br/>SubscriptionTier, UserStatus, etc.)"]
    end

    subgraph Infrastructure["Infrastructure Layer (infra/)"]
        direction TB
        supa_auth_impl["Supabase Auth<br/>Repository Impl"]
        supa_blocking_impl["Supabase Blocking<br/>Repository Impl"]
        supa_client["Supabase Client<br/>(Singleton)"]
        native_bridge["Native Platform Bridge<br/>(Flutter MethodChannel)"]
        perm_service["Permission Service"]
    end

    subgraph External["External Services"]
        direction TB
        supabase_be["Supabase Backend<br/>(PostgreSQL + GoTrue Auth)"]
        google["Google Sign-In"]
        apple["Sign in with Apple"]
        android_os["Android OS<br/>(AccessibilityService,<br/>UsageStats, Overlay)"]
        ios_os["iOS<br/>(FamilyControls,<br/>FamilyActivityPicker)"]
        dotenv[".env Configuration<br/>(SUPABASE_URL, ANON_KEY)"]
    end

    %% User to Presentation
    mobile --> auth_screens
    mobile --> blocking_screens
    mobile --> dashboard_screens

    %% Views to ViewModels
    auth_screens --> auth_vm
    blocking_screens --> blocking_vm
    dashboard_screens --> dashboard_vm
    log_screens --> log_vm

    %% ViewModels to Domain
    auth_vm -->|"calls"| repo_interfaces
    blocking_vm -->|"calls"| repo_interfaces
    dashboard_vm -->|"calls"| repo_interfaces
    log_vm -->|"calls"| repo_interfaces
    repo_interfaces --> entities
    repo_interfaces --> enums

    %% Domain to Infrastructure (implements)
    repo_interfaces -.->|"implemented by"| supa_auth_impl
    repo_interfaces -.->|"implemented by"| supa_blocking_impl

    %% Infrastructure internal
    supa_auth_impl --> supa_client
    supa_blocking_impl --> supa_client
    blocking_vm --> native_bridge
    blocking_vm --> perm_service

    %% Infrastructure to External
    supa_client -->|"HTTPS REST"| supabase_be
    supa_auth_impl -->|"OAuth"| google
    supa_auth_impl -->|"OAuth"| apple
    native_bridge -->|"MethodChannel"| android_os
    native_bridge -->|"MethodChannel"| ios_os
    supa_client --> dotenv

    %% Coordinator
    coordinator -.->|"navigates"| auth_screens
    coordinator -.->|"navigates"| blocking_screens
    coordinator -.->|"navigates"| dashboard_screens
    coordinator -.->|"navigates"| log_screens
    coordinator -.->|"navigates"| onboarding_screens
    coordinator -.->|"navigates"| subscription_screens

    %% Styling
    classDef presentation fill:#a5d8ff,stroke:#4a9eed,color:#1e1e1e
    classDef domain fill:#d0bfff,stroke:#8b5cf6,color:#1e1e1e
    classDef infra fill:#b2f2bb,stroke:#22c55e,color:#1e1e1e
    classDef external fill:#ffd8a8,stroke:#f59e0b,color:#1e1e1e
    classDef os fill:#ffc9c9,stroke:#ef4444,color:#1e1e1e
    classDef nav fill:#fff3bf,stroke:#f59e0b,color:#1e1e1e

    class auth_screens,blocking_screens,dashboard_screens,log_screens,onboarding_screens,subscription_screens,auth_vm,blocking_vm,dashboard_vm,log_vm presentation
    class entities,repo_interfaces,enums domain
    class supa_auth_impl,supa_blocking_impl,supa_client,native_bridge,perm_service infra
    class supabase_be,google,apple,dotenv external
    class android_os,ios_os os
    class coordinator,shared nav
```

## Data Flow Summary

1. **Auth Flow**: User → Auth Screens → AuthViewModel → AuthRepository Interface → SupabaseAuthRepository Impl → Supabase GoTrue / Google / Apple
2. **Blocking Flow**: User → Blocking Screens → BlockingViewModel → BlockingRepository Interface → SupabaseBlockingRepository Impl → Supabase DB + Native Platform Bridge → Android/iOS OS
3. **Navigation**: AppCoordinator holds GlobalKey\<NavigatorState\> and routes between all feature screens via AppRouter's onGenerateRoute
4. **All DB Access**: ViewModels → Abstract Repository Interfaces → Concrete Supabase Implementations → Supabase Client Singleton → HTTPS to Supabase Backend
