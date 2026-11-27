export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      achievement_definitions: {
        Row: {
          category: Database["public"]["Enums"]["achievement_category_enum"]
          code: string
          created_at: string
          criteria_type: Database["public"]["Enums"]["achievement_criteria_enum"]
          description: string
          icon_reference: string | null
          id: string
          is_active: boolean
          name: string
          reward_amount: number
          reward_type: Database["public"]["Enums"]["reward_type_enum"]
          target_value: number
          updated_at: string
        }
        Insert: {
          category: Database["public"]["Enums"]["achievement_category_enum"]
          code: string
          created_at?: string
          criteria_type: Database["public"]["Enums"]["achievement_criteria_enum"]
          description: string
          icon_reference?: string | null
          id?: string
          is_active?: boolean
          name: string
          reward_amount?: number
          reward_type?: Database["public"]["Enums"]["reward_type_enum"]
          target_value: number
          updated_at?: string
        }
        Update: {
          category?: Database["public"]["Enums"]["achievement_category_enum"]
          code?: string
          created_at?: string
          criteria_type?: Database["public"]["Enums"]["achievement_criteria_enum"]
          description?: string
          icon_reference?: string | null
          id?: string
          is_active?: boolean
          name?: string
          reward_amount?: number
          reward_type?: Database["public"]["Enums"]["reward_type_enum"]
          target_value?: number
          updated_at?: string
        }
        Relationships: []
      }
      app_usage_insights: {
        Row: {
          app_breakdown: Json | null
          created_at: string | null
          id: string
          total_screen_time_minutes: number | null
          usage_date: string
          user_id: string
        }
        Insert: {
          app_breakdown?: Json | null
          created_at?: string | null
          id?: string
          total_screen_time_minutes?: number | null
          usage_date: string
          user_id: string
        }
        Update: {
          app_breakdown?: Json | null
          created_at?: string | null
          id?: string
          total_screen_time_minutes?: number | null
          usage_date?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "app_usage_insights_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      blocking_rules: {
        Row: {
          created_at: string | null
          id: string
          item_identifier: string
          item_type: Database["public"]["Enums"]["item_type_enum"]
          status: Database["public"]["Enums"]["rule_status_enum"] | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          item_identifier: string
          item_type: Database["public"]["Enums"]["item_type_enum"]
          status?: Database["public"]["Enums"]["rule_status_enum"] | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          item_identifier?: string
          item_type?: Database["public"]["Enums"]["item_type_enum"]
          status?: Database["public"]["Enums"]["rule_status_enum"] | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "blocking_rules_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_account_deletion_jobs: {
        Row: {
          account_scope: string
          completed_at: string | null
          created_at: string
          family_household_ids: string[]
          id: string
          last_error: string | null
          pending_storage_paths: string[]
          profile_id: string
          removed_storage_paths: string[]
          requested_by_user_id: string
          status: string
          updated_at: string
        }
        Insert: {
          account_scope: string
          completed_at?: string | null
          created_at?: string
          family_household_ids?: string[]
          id?: string
          last_error?: string | null
          pending_storage_paths?: string[]
          profile_id: string
          removed_storage_paths?: string[]
          requested_by_user_id: string
          status: string
          updated_at?: string
        }
        Update: {
          account_scope?: string
          completed_at?: string | null
          created_at?: string
          family_household_ids?: string[]
          id?: string
          last_error?: string | null
          pending_storage_paths?: string[]
          profile_id?: string
          removed_storage_paths?: string[]
          requested_by_user_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      bloom_account_export_requests: {
        Row: {
          created_at: string
          file_count: number
          id: string
          profile_id: string
          requested_by_user_id: string
          status: string
        }
        Insert: {
          created_at?: string
          file_count?: number
          id?: string
          profile_id: string
          requested_by_user_id: string
          status: string
        }
        Update: {
          created_at?: string
          file_count?: number
          id?: string
          profile_id?: string
          requested_by_user_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_account_export_requests_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_billing_events: {
        Row: {
          event_type: string
          id: string
          processed_at: string | null
          provider: string
          provider_event_id: string
          received_at: string
          subscription_id: string | null
        }
        Insert: {
          event_type: string
          id?: string
          processed_at?: string | null
          provider: string
          provider_event_id: string
          received_at?: string
          subscription_id?: string | null
        }
        Update: {
          event_type?: string
          id?: string
          processed_at?: string | null
          provider?: string
          provider_event_id?: string
          received_at?: string
          subscription_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bloom_billing_events_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "bloom_subscriptions"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_blocking_rules: {
        Row: {
          created_at: string
          enabled: boolean
          id: string
          platform: string
          target_identifier: string
          target_type: string
          user_id: string
        }
        Insert: {
          created_at?: string
          enabled?: boolean
          id?: string
          platform: string
          target_identifier: string
          target_type: string
          user_id: string
        }
        Update: {
          created_at?: string
          enabled?: boolean
          id?: string
          platform?: string
          target_identifier?: string
          target_type?: string
          user_id?: string
        }
        Relationships: []
      }
      bloom_child_module_assignments: {
        Row: {
          assigned: boolean
          module_id: string
          profile_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          assigned: boolean
          module_id: string
          profile_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          assigned?: boolean
          module_id?: string
          profile_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bloom_child_module_assignments_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_child_module_assignments_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_child_profiles: {
        Row: {
          created_at: string
          created_by: string | null
          display_name: string
          household_id: string
          profile_id: string
          request_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          display_name: string
          household_id: string
          profile_id: string
          request_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          display_name?: string
          household_id?: string
          profile_id?: string
          request_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_child_profiles_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "bloom_households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_child_profiles_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_coach_messages: {
        Row: {
          content: string
          created_at: string
          id: string
          profile_id: string
          request_id: string
          role: string
        }
        Insert: {
          content: string
          created_at?: string
          id?: string
          profile_id: string
          request_id: string
          role: string
        }
        Update: {
          content?: string
          created_at?: string
          id?: string
          profile_id?: string
          request_id?: string
          role?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_coach_messages_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_coach_proposals: {
        Row: {
          base_plan_id: string | null
          base_revision: string | null
          base_updated_at: string | null
          created_at: string
          decided_at: string | null
          id: string
          profile_id: string
          proposal: Json
          request_id: string
          result_plan_id: string | null
          status: string
        }
        Insert: {
          base_plan_id?: string | null
          base_revision?: string | null
          base_updated_at?: string | null
          created_at?: string
          decided_at?: string | null
          id?: string
          profile_id: string
          proposal: Json
          request_id: string
          result_plan_id?: string | null
          status?: string
        }
        Update: {
          base_plan_id?: string | null
          base_revision?: string | null
          base_updated_at?: string | null
          created_at?: string
          decided_at?: string | null
          id?: string
          profile_id?: string
          proposal?: Json
          request_id?: string
          result_plan_id?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_coach_proposals_base_plan_id_fkey"
            columns: ["base_plan_id"]
            isOneToOne: false
            referencedRelation: "bloom_workout_plans"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_coach_proposals_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_coach_proposals_result_plan_id_fkey"
            columns: ["result_plan_id"]
            isOneToOne: false
            referencedRelation: "bloom_workout_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_coach_settings: {
        Row: {
          adult_attested: boolean
          equipment: string[]
          experience: string
          goals: string
          minor_eligible_attested: boolean
          parent_enabled: boolean
          parent_sharing_consent: boolean
          profile_id: string
          sharing_consent: boolean
          updated_at: string
        }
        Insert: {
          adult_attested?: boolean
          equipment?: string[]
          experience?: string
          goals?: string
          minor_eligible_attested?: boolean
          parent_enabled?: boolean
          parent_sharing_consent?: boolean
          profile_id: string
          sharing_consent?: boolean
          updated_at?: string
        }
        Update: {
          adult_attested?: boolean
          equipment?: string[]
          experience?: string
          goals?: string
          minor_eligible_attested?: boolean
          parent_enabled?: boolean
          parent_sharing_consent?: boolean
          profile_id?: string
          sharing_consent?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_coach_settings_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_competition_badges: {
        Row: {
          awarded_at: string
          competition_id: string
          profile_id: string
        }
        Insert: {
          awarded_at?: string
          competition_id: string
          profile_id: string
        }
        Update: {
          awarded_at?: string
          competition_id?: string
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_competition_badges_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "bloom_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_competition_badges_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_competition_friend_invites: {
        Row: {
          accepted_at: string | null
          competition_id: string
          created_at: string
          invited_by: string
          invitee_id: string
        }
        Insert: {
          accepted_at?: string | null
          competition_id: string
          created_at?: string
          invited_by: string
          invitee_id: string
        }
        Update: {
          accepted_at?: string | null
          competition_id?: string
          created_at?: string
          invited_by?: string
          invitee_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_competition_friend_invites_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "bloom_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_competition_friend_invites_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_competition_friend_invites_invitee_id_fkey"
            columns: ["invitee_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_competition_participants: {
        Row: {
          approved_at: string | null
          competition_id: string
          profile_id: string
          requested_at: string
          status: string
        }
        Insert: {
          approved_at?: string | null
          competition_id: string
          profile_id: string
          requested_at?: string
          status: string
        }
        Update: {
          approved_at?: string | null
          competition_id?: string
          profile_id?: string
          requested_at?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_competition_participants_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "bloom_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_competition_participants_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_competitions: {
        Row: {
          created_at: string
          description: string
          ends_at: string
          finalized_at: string | null
          id: string
          max_participants: number
          metric: string
          owner_profile_id: string
          published_at: string | null
          starts_at: string
          status: string
          title: string
          visibility: string
        }
        Insert: {
          created_at?: string
          description?: string
          ends_at: string
          finalized_at?: string | null
          id?: string
          max_participants: number
          metric: string
          owner_profile_id: string
          published_at?: string | null
          starts_at: string
          status: string
          title: string
          visibility: string
        }
        Update: {
          created_at?: string
          description?: string
          ends_at?: string
          finalized_at?: string | null
          id?: string
          max_participants?: number
          metric?: string
          owner_profile_id?: string
          published_at?: string | null
          starts_at?: string
          status?: string
          title?: string
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_competitions_owner_profile_id_fkey"
            columns: ["owner_profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_credit_ledger: {
        Row: {
          amount_minutes: number
          created_at: string
          entry_type: string
          expires_at: string | null
          growth_module_id: string | null
          growth_source_id: string | null
          growth_source_type: string | null
          id: string
          idempotency_key: string
          user_id: string
          workout_session_id: string | null
        }
        Insert: {
          amount_minutes: number
          created_at?: string
          entry_type: string
          expires_at?: string | null
          growth_module_id?: string | null
          growth_source_id?: string | null
          growth_source_type?: string | null
          id?: string
          idempotency_key: string
          user_id: string
          workout_session_id?: string | null
        }
        Update: {
          amount_minutes?: number
          created_at?: string
          entry_type?: string
          expires_at?: string | null
          growth_module_id?: string | null
          growth_source_id?: string | null
          growth_source_type?: string | null
          id?: string
          idempotency_key?: string
          user_id?: string
          workout_session_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bloom_credit_ledger_workout_session_id_fkey"
            columns: ["workout_session_id"]
            isOneToOne: false
            referencedRelation: "bloom_workout_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_credit_sessions: {
        Row: {
          ends_at: string
          enforced: boolean
          expires_at: string
          id: string
          mode: string
          request_id: string
          settled_at: string | null
          started_at: string
          user_id: string
        }
        Insert: {
          ends_at: string
          enforced?: boolean
          expires_at: string
          id?: string
          mode: string
          request_id: string
          settled_at?: string | null
          started_at: string
          user_id: string
        }
        Update: {
          ends_at?: string
          enforced?: boolean
          expires_at?: string
          id?: string
          mode?: string
          request_id?: string
          settled_at?: string | null
          started_at?: string
          user_id?: string
        }
        Relationships: []
      }
      bloom_devices: {
        Row: {
          auth_session_id: string | null
          blocking_state: string
          device_id: string
          display_name: string
          first_seen_at: string
          focus_supported: boolean | null
          last_seen_at: string
          permission_state: string
          platform: string
          profile_id: string
          removed_at: string | null
          revoked_at: string | null
          selected_target_count: number | null
          status_checked_at: string
          updated_at: string
        }
        Insert: {
          auth_session_id?: string | null
          blocking_state: string
          device_id: string
          display_name: string
          first_seen_at?: string
          focus_supported?: boolean | null
          last_seen_at?: string
          permission_state: string
          platform: string
          profile_id: string
          removed_at?: string | null
          revoked_at?: string | null
          selected_target_count?: number | null
          status_checked_at?: string
          updated_at?: string
        }
        Update: {
          auth_session_id?: string | null
          blocking_state?: string
          device_id?: string
          display_name?: string
          first_seen_at?: string
          focus_supported?: boolean | null
          last_seen_at?: string
          permission_state?: string
          platform?: string
          profile_id?: string
          removed_at?: string | null
          revoked_at?: string | null
          selected_target_count?: number | null
          status_checked_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_devices_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_document_help_answers: {
        Row: {
          answer: string
          citations: Json
          created_at: string
          document_id: string
          id: string
          profile_id: string
          question: string
          request_id: string
          uncertainty: string
        }
        Insert: {
          answer: string
          citations: Json
          created_at?: string
          document_id: string
          id?: string
          profile_id: string
          question: string
          request_id: string
          uncertainty: string
        }
        Update: {
          answer?: string
          citations?: Json
          created_at?: string
          document_id?: string
          id?: string
          profile_id?: string
          question?: string
          request_id?: string
          uncertainty?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_document_help_answers_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "bloom_growth_documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_document_help_answers_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_friendships: {
        Row: {
          addressee_id: string
          created_at: string
          id: string
          requester_id: string
          status: string
          updated_at: string
        }
        Insert: {
          addressee_id: string
          created_at?: string
          id?: string
          requester_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          addressee_id?: string
          created_at?: string
          id?: string
          requester_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_friendships_addressee_id_fkey"
            columns: ["addressee_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_friendships_requester_id_fkey"
            columns: ["requester_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_growth_ai_settings: {
        Row: {
          adult_attested: boolean
          document_adult_attested: boolean
          document_minor_eligible_attested: boolean
          document_parent_enabled: boolean
          document_parent_sharing_consent: boolean
          document_sharing_consent: boolean
          minor_eligible_attested: boolean
          module_id: string
          parent_enabled: boolean
          parent_sharing_consent: boolean
          profile_id: string
          sharing_consent: boolean
          updated_at: string
        }
        Insert: {
          adult_attested?: boolean
          document_adult_attested?: boolean
          document_minor_eligible_attested?: boolean
          document_parent_enabled?: boolean
          document_parent_sharing_consent?: boolean
          document_sharing_consent?: boolean
          minor_eligible_attested?: boolean
          module_id: string
          parent_enabled?: boolean
          parent_sharing_consent?: boolean
          profile_id: string
          sharing_consent?: boolean
          updated_at?: string
        }
        Update: {
          adult_attested?: boolean
          document_adult_attested?: boolean
          document_minor_eligible_attested?: boolean
          document_parent_enabled?: boolean
          document_parent_sharing_consent?: boolean
          document_sharing_consent?: boolean
          minor_eligible_attested?: boolean
          module_id?: string
          parent_enabled?: boolean
          parent_sharing_consent?: boolean
          profile_id?: string
          sharing_consent?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_growth_ai_settings_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_growth_documents: {
        Row: {
          byte_size: number
          created_at: string
          file_name: string
          format: string
          id: string
          item_id: string
          mime_type: string
          module_id: string
          profile_id: string
          request_id: string
          status: string
          storage_path: string
          title: string
          updated_at: string
        }
        Insert: {
          byte_size: number
          created_at?: string
          file_name: string
          format: string
          id?: string
          item_id: string
          mime_type: string
          module_id: string
          profile_id: string
          request_id: string
          status?: string
          storage_path: string
          title: string
          updated_at?: string
        }
        Update: {
          byte_size?: number
          created_at?: string
          file_name?: string
          format?: string
          id?: string
          item_id?: string
          mime_type?: string
          module_id?: string
          profile_id?: string
          request_id?: string
          status?: string
          storage_path?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_growth_documents_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "bloom_growth_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_growth_documents_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_growth_items: {
        Row: {
          artwork_id: string | null
          author: string
          completed_at: string | null
          created_at: string
          current_page: number | null
          due_date: string | null
          genre: string
          id: string
          item_type: string
          module_id: string
          notes: string
          page_count: number | null
          parent_id: string | null
          postponed_until: string | null
          priority: string
          profile_id: string
          progress_percent: number
          reading_kind: string | null
          reading_status: string | null
          request_id: string
          state: string
          target_minutes: number | null
          title: string
          updated_at: string
        }
        Insert: {
          artwork_id?: string | null
          author?: string
          completed_at?: string | null
          created_at?: string
          current_page?: number | null
          due_date?: string | null
          genre?: string
          id?: string
          item_type: string
          module_id: string
          notes?: string
          page_count?: number | null
          parent_id?: string | null
          postponed_until?: string | null
          priority?: string
          profile_id: string
          progress_percent?: number
          reading_kind?: string | null
          reading_status?: string | null
          request_id: string
          state?: string
          target_minutes?: number | null
          title: string
          updated_at?: string
        }
        Update: {
          artwork_id?: string | null
          author?: string
          completed_at?: string | null
          created_at?: string
          current_page?: number | null
          due_date?: string | null
          genre?: string
          id?: string
          item_type?: string
          module_id?: string
          notes?: string
          page_count?: number | null
          parent_id?: string | null
          postponed_until?: string | null
          priority?: string
          profile_id?: string
          progress_percent?: number
          reading_kind?: string | null
          reading_status?: string | null
          request_id?: string
          state?: string
          target_minutes?: number | null
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_growth_items_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "bloom_growth_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_growth_items_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_growth_memory: {
        Row: {
          automatic_default: boolean
          enabled: boolean
          profile_id: string
          shared_domains: string[]
          summaries: Json
          updated_at: string
        }
        Insert: {
          automatic_default?: boolean
          enabled?: boolean
          profile_id: string
          shared_domains?: string[]
          summaries?: Json
          updated_at?: string
        }
        Update: {
          automatic_default?: boolean
          enabled?: boolean
          profile_id?: string
          shared_domains?: string[]
          summaries?: Json
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_growth_memory_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_growth_record_attachments: {
        Row: {
          created_at: string
          document_id: string
          profile_id: string
          record_id: string
        }
        Insert: {
          created_at?: string
          document_id: string
          profile_id: string
          record_id: string
        }
        Update: {
          created_at?: string
          document_id?: string
          profile_id?: string
          record_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_growth_record_attachments_document_fk"
            columns: ["profile_id", "document_id"]
            isOneToOne: false
            referencedRelation: "bloom_growth_documents"
            referencedColumns: ["profile_id", "id"]
          },
          {
            foreignKeyName: "bloom_growth_record_attachments_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_growth_record_attachments_record_fk"
            columns: ["profile_id", "record_id"]
            isOneToOne: false
            referencedRelation: "bloom_growth_records"
            referencedColumns: ["profile_id", "id"]
          },
        ]
      }
      bloom_growth_records: {
        Row: {
          body: string
          created_at: string
          id: string
          item_id: string | null
          kind: string
          metadata: Json
          module_id: string
          profile_id: string
          request_id: string
          scheduled_at: string | null
          score: number | null
          title: string
          updated_at: string
        }
        Insert: {
          body?: string
          created_at?: string
          id?: string
          item_id?: string | null
          kind: string
          metadata?: Json
          module_id: string
          profile_id: string
          request_id: string
          scheduled_at?: string | null
          score?: number | null
          title: string
          updated_at?: string
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          item_id?: string | null
          kind?: string
          metadata?: Json
          module_id?: string
          profile_id?: string
          request_id?: string
          scheduled_at?: string | null
          score?: number | null
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_growth_records_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "bloom_growth_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_growth_records_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_growth_reward_events: {
        Row: {
          awarded_minutes: number
          created_at: string
          id: string
          module_id: string
          profile_id: string
          requested_minutes: number
          reviewed_at: string | null
          reviewed_by: string | null
          source_id: string
          source_type: string
          status: string
        }
        Insert: {
          awarded_minutes?: number
          created_at?: string
          id?: string
          module_id: string
          profile_id: string
          requested_minutes: number
          reviewed_at?: string | null
          reviewed_by?: string | null
          source_id: string
          source_type: string
          status?: string
        }
        Update: {
          awarded_minutes?: number
          created_at?: string
          id?: string
          module_id?: string
          profile_id?: string
          requested_minutes?: number
          reviewed_at?: string | null
          reviewed_by?: string | null
          source_id?: string
          source_type?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_growth_reward_events_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_growth_reward_events_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_growth_reward_rules: {
        Row: {
          daily_cap_minutes: number
          enabled: boolean
          minimum_session_minutes: number
          module_id: string
          profile_id: string
          require_parent_approval: boolean
          reward_minutes: number
          updated_at: string
          updated_by: string
          weekly_cap_minutes: number
        }
        Insert: {
          daily_cap_minutes?: number
          enabled?: boolean
          minimum_session_minutes?: number
          module_id: string
          profile_id: string
          require_parent_approval?: boolean
          reward_minutes?: number
          updated_at?: string
          updated_by: string
          weekly_cap_minutes?: number
        }
        Update: {
          daily_cap_minutes?: number
          enabled?: boolean
          minimum_session_minutes?: number
          module_id?: string
          profile_id?: string
          require_parent_approval?: boolean
          reward_minutes?: number
          updated_at?: string
          updated_by?: string
          weekly_cap_minutes?: number
        }
        Relationships: [
          {
            foreignKeyName: "bloom_growth_reward_rules_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_growth_reward_rules_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_growth_sessions: {
        Row: {
          completed_at: string | null
          duration_seconds: number | null
          id: string
          item_id: string
          module_id: string
          offline_self_reported: boolean
          profile_id: string
          request_id: string
          source_device_id: string
          source_device_name: string
          started_at: string
          status: string
        }
        Insert: {
          completed_at?: string | null
          duration_seconds?: number | null
          id?: string
          item_id: string
          module_id: string
          offline_self_reported?: boolean
          profile_id: string
          request_id: string
          source_device_id: string
          source_device_name: string
          started_at?: string
          status?: string
        }
        Update: {
          completed_at?: string | null
          duration_seconds?: number | null
          id?: string
          item_id?: string
          module_id?: string
          offline_self_reported?: boolean
          profile_id?: string
          request_id?: string
          source_device_id?: string
          source_device_name?: string
          started_at?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_growth_sessions_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "bloom_growth_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_growth_sessions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_household_members: {
        Row: {
          household_id: string
          joined_at: string
          role: string
          user_id: string
        }
        Insert: {
          household_id: string
          joined_at?: string
          role: string
          user_id: string
        }
        Update: {
          household_id?: string
          joined_at?: string
          role?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_household_members_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "bloom_households"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_households: {
        Row: {
          created_at: string
          id: string
          name: string
          owner_user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          owner_user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          owner_user_id?: string
        }
        Relationships: []
      }
      bloom_plan_entitlements: {
        Row: {
          enabled: boolean
          entitlement_key: string
          plan_id: string
        }
        Insert: {
          enabled?: boolean
          entitlement_key: string
          plan_id: string
        }
        Update: {
          enabled?: boolean
          entitlement_key?: string
          plan_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_plan_entitlements_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "bloom_subscription_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_plan_exercises: {
        Row: {
          exercise_id: string
          plan_id: string
          position: number
          sets: number
          target_distance_km: number | null
          target_reps: number | null
          target_seconds: number | null
          target_weight_kg: number | null
        }
        Insert: {
          exercise_id: string
          plan_id: string
          position: number
          sets?: number
          target_distance_km?: number | null
          target_reps?: number | null
          target_seconds?: number | null
          target_weight_kg?: number | null
        }
        Update: {
          exercise_id?: string
          plan_id?: string
          position?: number
          sets?: number
          target_distance_km?: number | null
          target_reps?: number | null
          target_seconds?: number | null
          target_weight_kg?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "bloom_plan_exercises_exercise_id_fkey"
            columns: ["exercise_id"]
            isOneToOne: false
            referencedRelation: "exercises"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_plan_exercises_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "bloom_workout_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_profile_accounts: {
        Row: {
          created_at: string
          profile_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          profile_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          profile_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_profile_accounts_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_profiles: {
        Row: {
          created_at: string
          id: string
        }
        Insert: {
          created_at?: string
          id?: string
        }
        Update: {
          created_at?: string
          id?: string
        }
        Relationships: []
      }
      bloom_settings: {
        Row: {
          created_at: string
          credit_mode: string
          credit_timezone: string
          credits_enabled: boolean
          earning_strategy: string
          exercise_minutes_per_award: number | null
          rep_award_minutes: number | null
          reps_per_award: number | null
          super_daily_cap_minutes: number | null
          time_award_minutes: number | null
          updated_at: string
          user_id: string
          weekly_credit_target_minutes: number | null
          weekly_earning_cap_minutes: number | null
          weekly_workout_target: number | null
        }
        Insert: {
          created_at?: string
          credit_mode?: string
          credit_timezone?: string
          credits_enabled?: boolean
          earning_strategy?: string
          exercise_minutes_per_award?: number | null
          rep_award_minutes?: number | null
          reps_per_award?: number | null
          super_daily_cap_minutes?: number | null
          time_award_minutes?: number | null
          updated_at?: string
          user_id: string
          weekly_credit_target_minutes?: number | null
          weekly_earning_cap_minutes?: number | null
          weekly_workout_target?: number | null
        }
        Update: {
          created_at?: string
          credit_mode?: string
          credit_timezone?: string
          credits_enabled?: boolean
          earning_strategy?: string
          exercise_minutes_per_award?: number | null
          rep_award_minutes?: number | null
          reps_per_award?: number | null
          super_daily_cap_minutes?: number | null
          time_award_minutes?: number | null
          updated_at?: string
          user_id?: string
          weekly_credit_target_minutes?: number | null
          weekly_earning_cap_minutes?: number | null
          weekly_workout_target?: number | null
        }
        Relationships: []
      }
      bloom_social_profiles: {
        Row: {
          child_search_opt_in: boolean
          display_name: string
          profile_id: string
          searchable: boolean
          updated_at: string
        }
        Insert: {
          child_search_opt_in?: boolean
          display_name: string
          profile_id: string
          searchable?: boolean
          updated_at?: string
        }
        Update: {
          child_search_opt_in?: boolean
          display_name?: string
          profile_id?: string
          searchable?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_social_profiles_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_study_plan_changes: {
        Row: {
          action: string
          created_at: string
          id: string
          item_id: string
          moved_to_date: string | null
          original_date: string
          profile_id: string
        }
        Insert: {
          action: string
          created_at?: string
          id?: string
          item_id: string
          moved_to_date?: string | null
          original_date: string
          profile_id: string
        }
        Update: {
          action?: string
          created_at?: string
          id?: string
          item_id?: string
          moved_to_date?: string | null
          original_date?: string
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_study_plan_changes_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "bloom_growth_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_study_plan_changes_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_study_plan_slots: {
        Row: {
          created_at: string
          day_of_week: number
          id: string
          item_id: string
          profile_id: string
          target_minutes: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          day_of_week: number
          id?: string
          item_id: string
          profile_id: string
          target_minutes: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          day_of_week?: number
          id?: string
          item_id?: string
          profile_id?: string
          target_minutes?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_study_plan_slots_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "bloom_growth_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_study_plan_slots_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_study_tutor_messages: {
        Row: {
          answer_scope: string | null
          content: string
          created_at: string
          id: string
          item_id: string
          profile_id: string
          request_id: string
          role: string
          uncertainty: string | null
        }
        Insert: {
          answer_scope?: string | null
          content: string
          created_at?: string
          id?: string
          item_id: string
          profile_id: string
          request_id: string
          role: string
          uncertainty?: string | null
        }
        Update: {
          answer_scope?: string | null
          content?: string
          created_at?: string
          id?: string
          item_id?: string
          profile_id?: string
          request_id?: string
          role?: string
          uncertainty?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bloom_study_tutor_messages_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "bloom_growth_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_study_tutor_messages_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_subscription_plans: {
        Row: {
          active: boolean
          display_name: string
          id: string
        }
        Insert: {
          active?: boolean
          display_name: string
          id: string
        }
        Update: {
          active?: boolean
          display_name?: string
          id?: string
        }
        Relationships: []
      }
      bloom_subscription_products: {
        Row: {
          active: boolean
          billing_period: string
          id: string
          plan_id: string
          provider: string
          provider_product_id: string
          scope: string
        }
        Insert: {
          active?: boolean
          billing_period: string
          id?: string
          plan_id: string
          provider: string
          provider_product_id: string
          scope: string
        }
        Update: {
          active?: boolean
          billing_period?: string
          id?: string
          plan_id?: string
          provider?: string
          provider_product_id?: string
          scope?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_subscription_products_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "bloom_subscription_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_subscriptions: {
        Row: {
          cancel_at_period_end: boolean
          created_at: string
          current_period_end: string | null
          current_period_start: string | null
          household_id: string | null
          id: string
          payer_user_id: string
          product_id: string
          provider_subscription_id: string
          status: string
        }
        Insert: {
          cancel_at_period_end?: boolean
          created_at?: string
          current_period_end?: string | null
          current_period_start?: string | null
          household_id?: string | null
          id?: string
          payer_user_id: string
          product_id: string
          provider_subscription_id: string
          status: string
        }
        Update: {
          cancel_at_period_end?: boolean
          created_at?: string
          current_period_end?: string | null
          current_period_start?: string | null
          household_id?: string | null
          id?: string
          payer_user_id?: string
          product_id?: string
          provider_subscription_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_subscriptions_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "bloom_households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_subscriptions_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "bloom_subscription_products"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_task_focus_sessions: {
        Row: {
          completed_at: string | null
          duration_seconds: number | null
          id: string
          profile_id: string
          request_id: string
          started_at: string
          status: string
          task_id: string
        }
        Insert: {
          completed_at?: string | null
          duration_seconds?: number | null
          id?: string
          profile_id: string
          request_id: string
          started_at?: string
          status?: string
          task_id: string
        }
        Update: {
          completed_at?: string | null
          duration_seconds?: number | null
          id?: string
          profile_id?: string
          request_id?: string
          started_at?: string
          status?: string
          task_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_task_focus_sessions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_task_focus_sessions_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "bloom_growth_items"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_usage_sessions: {
        Row: {
          abandoned_at: string | null
          access_expires_at: string
          billing_started_at: string | null
          expires_at: string
          id: string
          request_id: string
          requested_ms: number
          reserved_ms: number
          settled_at: string | null
          started_at: string
          used_ms: number | null
          user_id: string
        }
        Insert: {
          abandoned_at?: string | null
          access_expires_at: string
          billing_started_at?: string | null
          expires_at: string
          id?: string
          request_id: string
          requested_ms: number
          reserved_ms: number
          settled_at?: string | null
          started_at?: string
          used_ms?: number | null
          user_id: string
        }
        Update: {
          abandoned_at?: string | null
          access_expires_at?: string
          billing_started_at?: string | null
          expires_at?: string
          id?: string
          request_id?: string
          requested_ms?: number
          reserved_ms?: number
          settled_at?: string | null
          started_at?: string
          used_ms?: number | null
          user_id?: string
        }
        Relationships: []
      }
      bloom_website_rules: {
        Row: {
          created_at: string
          created_by: string
          domain: string
          id: string
          scope: string
          user_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string
          domain: string
          id?: string
          scope: string
          user_id: string
        }
        Update: {
          created_at?: string
          created_by?: string
          domain?: string
          id?: string
          scope?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_website_rules_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bloom_website_rules_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_weekly_pillar_goals: {
        Row: {
          active_days: number[]
          module_id: string
          profile_id: string
          target_count: number
          unit: string
          updated_at: string
        }
        Insert: {
          active_days: number[]
          module_id: string
          profile_id: string
          target_count: number
          unit: string
          updated_at?: string
        }
        Update: {
          active_days?: number[]
          module_id?: string
          profile_id?: string
          target_count?: number
          unit?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_weekly_pillar_goals_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "bloom_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bloom_workout_plans: {
        Row: {
          created_at: string
          id: string
          scheduled_days: number[]
          source: string
          title: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          scheduled_days?: number[]
          source?: string
          title: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          scheduled_days?: number[]
          source?: string
          title?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      bloom_workout_sessions: {
        Row: {
          active_duration_seconds: number | null
          client_activity_id: string | null
          completed_at: string | null
          credits_earned_minutes: number
          credits_enabled_at_completion: boolean | null
          exercise_results: Json
          id: string
          offline_self_reported: boolean
          plan_id: string | null
          plan_snapshot: Json
          plan_title_snapshot: string | null
          started_at: string
          status: string
          timer_started_at: string | null
          user_id: string
        }
        Insert: {
          active_duration_seconds?: number | null
          client_activity_id?: string | null
          completed_at?: string | null
          credits_earned_minutes?: number
          credits_enabled_at_completion?: boolean | null
          exercise_results?: Json
          id?: string
          offline_self_reported?: boolean
          plan_id?: string | null
          plan_snapshot: Json
          plan_title_snapshot?: string | null
          started_at?: string
          status?: string
          timer_started_at?: string | null
          user_id: string
        }
        Update: {
          active_duration_seconds?: number | null
          client_activity_id?: string | null
          completed_at?: string | null
          credits_earned_minutes?: number
          credits_enabled_at_completion?: boolean | null
          exercise_results?: Json
          id?: string
          offline_self_reported?: boolean
          plan_id?: string | null
          plan_snapshot?: Json
          plan_title_snapshot?: string | null
          started_at?: string
          status?: string
          timer_started_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bloom_workout_sessions_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "bloom_workout_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      emergency_breaks: {
        Row: {
          duration_minutes: number
          granted_at: string | null
          id: string
          reason: string | null
          user_id: string
        }
        Insert: {
          duration_minutes: number
          granted_at?: string | null
          id?: string
          reason?: string | null
          user_id: string
        }
        Update: {
          duration_minutes?: number
          granted_at?: string | null
          id?: string
          reason?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "emergency_breaks_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      exercises: {
        Row: {
          bloom_owner_user_id: string | null
          created_at: string | null
          description: string | null
          difficulty_level: string | null
          id: string
          instructions: string[] | null
          is_system: boolean | null
          measurement_type: Database["public"]["Enums"]["exercise_measurement_enum"]
          media_id: string | null
          media_link: string | null
          muscle_group: string | null
          muscle_groups: string[] | null
          name: string
          steps: string[] | null
        }
        Insert: {
          bloom_owner_user_id?: string | null
          created_at?: string | null
          description?: string | null
          difficulty_level?: string | null
          id?: string
          instructions?: string[] | null
          is_system?: boolean | null
          measurement_type?: Database["public"]["Enums"]["exercise_measurement_enum"]
          media_id?: string | null
          media_link?: string | null
          muscle_group?: string | null
          muscle_groups?: string[] | null
          name: string
          steps?: string[] | null
        }
        Update: {
          bloom_owner_user_id?: string | null
          created_at?: string | null
          description?: string | null
          difficulty_level?: string | null
          id?: string
          instructions?: string[] | null
          is_system?: boolean | null
          measurement_type?: Database["public"]["Enums"]["exercise_measurement_enum"]
          media_id?: string | null
          media_link?: string | null
          muscle_group?: string | null
          muscle_groups?: string[] | null
          name?: string
          steps?: string[] | null
        }
        Relationships: [
          {
            foreignKeyName: "exercises_media_id_fkey"
            columns: ["media_id"]
            isOneToOne: false
            referencedRelation: "media"
            referencedColumns: ["id"]
          },
        ]
      }
      friendships: {
        Row: {
          addressee_id: string
          created_at: string | null
          id: string
          requester_id: string
          status: Database["public"]["Enums"]["friendship_status_enum"] | null
          updated_at: string | null
        }
        Insert: {
          addressee_id: string
          created_at?: string | null
          id?: string
          requester_id: string
          status?: Database["public"]["Enums"]["friendship_status_enum"] | null
          updated_at?: string | null
        }
        Update: {
          addressee_id?: string
          created_at?: string | null
          id?: string
          requester_id?: string
          status?: Database["public"]["Enums"]["friendship_status_enum"] | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "friendships_addressee_id_fkey"
            columns: ["addressee_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friendships_requester_id_fkey"
            columns: ["requester_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      leaderboard_members: {
        Row: {
          joined_at: string | null
          leaderboard_id: string
          user_id: string
          weekly_score: number | null
        }
        Insert: {
          joined_at?: string | null
          leaderboard_id: string
          user_id: string
          weekly_score?: number | null
        }
        Update: {
          joined_at?: string | null
          leaderboard_id?: string
          user_id?: string
          weekly_score?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "leaderboard_members_leaderboard_id_fkey"
            columns: ["leaderboard_id"]
            isOneToOne: false
            referencedRelation: "leaderboards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leaderboard_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      leaderboard_period_scores: {
        Row: {
          leaderboard_id: string
          period_end: string
          period_start: string
          score: number
          updated_at: string
          user_id: string
        }
        Insert: {
          leaderboard_id: string
          period_end: string
          period_start: string
          score?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          leaderboard_id?: string
          period_end?: string
          period_start?: string
          score?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "leaderboard_period_scores_member_fk"
            columns: ["leaderboard_id", "user_id"]
            isOneToOne: false
            referencedRelation: "leaderboard_members"
            referencedColumns: ["leaderboard_id", "user_id"]
          },
        ]
      }
      leaderboards: {
        Row: {
          created_at: string | null
          id: string
          invite_code: string
          is_active: boolean | null
          name: string
          owner_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          invite_code: string
          is_active?: boolean | null
          name: string
          owner_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          invite_code?: string
          is_active?: boolean | null
          name?: string
          owner_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "leaderboards_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      media: {
        Row: {
          created_at: string | null
          file_name: string | null
          id: string
          mime_type: string | null
          size_bytes: number | null
          storage_path: string
          type: Database["public"]["Enums"]["media_type_enum"] | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          file_name?: string | null
          id?: string
          mime_type?: string | null
          size_bytes?: number | null
          storage_path: string
          type?: Database["public"]["Enums"]["media_type_enum"] | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          file_name?: string | null
          id?: string
          mime_type?: string | null
          size_bytes?: number | null
          storage_path?: string
          type?: Database["public"]["Enums"]["media_type_enum"] | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "media_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string
          created_at: string | null
          id: string
          status: Database["public"]["Enums"]["notification_status_enum"] | null
          title: string
          type: string | null
          user_id: string
        }
        Insert: {
          body: string
          created_at?: string | null
          id?: string
          status?:
            | Database["public"]["Enums"]["notification_status_enum"]
            | null
          title: string
          type?: string | null
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string | null
          id?: string
          status?:
            | Database["public"]["Enums"]["notification_status_enum"]
            | null
          title?: string
          type?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      point_awards: {
        Row: {
          created_at: string
          description: string
          id: string
          points: number
          reason_type: Database["public"]["Enums"]["point_reason_enum"]
          source_event_id: string
          source_type: string
          user_id: string
          workout_log_id: string | null
        }
        Insert: {
          created_at?: string
          description: string
          id?: string
          points: number
          reason_type: Database["public"]["Enums"]["point_reason_enum"]
          source_event_id: string
          source_type: string
          user_id: string
          workout_log_id?: string | null
        }
        Update: {
          created_at?: string
          description?: string
          id?: string
          points?: number
          reason_type?: Database["public"]["Enums"]["point_reason_enum"]
          source_event_id?: string
          source_type?: string
          user_id?: string
          workout_log_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "point_awards_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "point_awards_workout_log_id_fkey"
            columns: ["workout_log_id"]
            isOneToOne: false
            referencedRelation: "workout_logs"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_media_id: string | null
          created_at: string | null
          daily_phone_hours: number
          email: string
          fcm_token: string | null
          first_name: string | null
          id: string
          last_name: string | null
          last_weekly_reset_at: string | null
          last_workout_date: string | null
          longest_streak: number
          points_total: number
          screen_time_balance_minutes: number | null
          status: Database["public"]["Enums"]["user_status_enum"] | null
          streak_count: number | null
          strict_blocking_only: boolean
          subscription_tier:
            | Database["public"]["Enums"]["subscription_tier_enum"]
            | null
          timezone: string
          updated_at: string | null
          username: string | null
          weekly_big_sessions: number
          weekly_exercise_target_minutes: number | null
          weekly_small_sessions: number
        }
        Insert: {
          avatar_media_id?: string | null
          created_at?: string | null
          daily_phone_hours?: number
          email: string
          fcm_token?: string | null
          first_name?: string | null
          id: string
          last_name?: string | null
          last_weekly_reset_at?: string | null
          last_workout_date?: string | null
          longest_streak?: number
          points_total?: number
          screen_time_balance_minutes?: number | null
          status?: Database["public"]["Enums"]["user_status_enum"] | null
          streak_count?: number | null
          strict_blocking_only?: boolean
          subscription_tier?:
            | Database["public"]["Enums"]["subscription_tier_enum"]
            | null
          timezone?: string
          updated_at?: string | null
          username?: string | null
          weekly_big_sessions?: number
          weekly_exercise_target_minutes?: number | null
          weekly_small_sessions?: number
        }
        Update: {
          avatar_media_id?: string | null
          created_at?: string | null
          daily_phone_hours?: number
          email?: string
          fcm_token?: string | null
          first_name?: string | null
          id?: string
          last_name?: string | null
          last_weekly_reset_at?: string | null
          last_workout_date?: string | null
          longest_streak?: number
          points_total?: number
          screen_time_balance_minutes?: number | null
          status?: Database["public"]["Enums"]["user_status_enum"] | null
          streak_count?: number | null
          strict_blocking_only?: boolean
          subscription_tier?:
            | Database["public"]["Enums"]["subscription_tier_enum"]
            | null
          timezone?: string
          updated_at?: string | null
          username?: string | null
          weekly_big_sessions?: number
          weekly_exercise_target_minutes?: number | null
          weekly_small_sessions?: number
        }
        Relationships: [
          {
            foreignKeyName: "profiles_avatar_media_id_fkey"
            columns: ["avatar_media_id"]
            isOneToOne: false
            referencedRelation: "media"
            referencedColumns: ["id"]
          },
        ]
      }
      screen_time_transactions: {
        Row: {
          amount_minutes: number
          created_at: string | null
          description: string | null
          id: string
          reference_id: string | null
          transaction_type: Database["public"]["Enums"]["transaction_type_enum"]
          user_id: string
        }
        Insert: {
          amount_minutes: number
          created_at?: string | null
          description?: string | null
          id?: string
          reference_id?: string | null
          transaction_type: Database["public"]["Enums"]["transaction_type_enum"]
          user_id: string
        }
        Update: {
          amount_minutes?: number
          created_at?: string | null
          description?: string | null
          id?: string
          reference_id?: string | null
          transaction_type?: Database["public"]["Enums"]["transaction_type_enum"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "screen_time_transactions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_achievements: {
        Row: {
          achievement_id: string
          created_at: string
          id: string
          progress: number
          reward_granted_at: string | null
          reward_transaction_id: string | null
          unlocked_at: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          achievement_id: string
          created_at?: string
          id?: string
          progress?: number
          reward_granted_at?: string | null
          reward_transaction_id?: string | null
          unlocked_at?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          achievement_id?: string
          created_at?: string
          id?: string
          progress?: number
          reward_granted_at?: string | null
          reward_transaction_id?: string | null
          unlocked_at?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_achievements_achievement_id_fkey"
            columns: ["achievement_id"]
            isOneToOne: false
            referencedRelation: "achievement_definitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_achievements_reward_transaction_id_fkey"
            columns: ["reward_transaction_id"]
            isOneToOne: false
            referencedRelation: "screen_time_transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_achievements_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_rewards: {
        Row: {
          id: string
          reward_description: string | null
          reward_title: string
          unlocked_at: string | null
          user_id: string
        }
        Insert: {
          id?: string
          reward_description?: string | null
          reward_title: string
          unlocked_at?: string | null
          user_id: string
        }
        Update: {
          id?: string
          reward_description?: string | null
          reward_title?: string
          unlocked_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_rewards_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      workout_logs: {
        Row: {
          completed_exercises: Json
          duration_minutes: number
          earned_screen_time_minutes: number
          id: string
          logged_at: string | null
          notes: string | null
          user_id: string
          workout_plan_id: string | null
          workout_session_id: string | null
        }
        Insert: {
          completed_exercises?: Json
          duration_minutes: number
          earned_screen_time_minutes: number
          id?: string
          logged_at?: string | null
          notes?: string | null
          user_id: string
          workout_plan_id?: string | null
          workout_session_id?: string | null
        }
        Update: {
          completed_exercises?: Json
          duration_minutes?: number
          earned_screen_time_minutes?: number
          id?: string
          logged_at?: string | null
          notes?: string | null
          user_id?: string
          workout_plan_id?: string | null
          workout_session_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "workout_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workout_logs_workout_plan_id_fkey"
            columns: ["workout_plan_id"]
            isOneToOne: false
            referencedRelation: "workout_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      workout_plans: {
        Row: {
          created_at: string | null
          description: string | null
          exercises: Json
          id: string
          scheduled_days: number[] | null
          session_size: string
          source: Database["public"]["Enums"]["workout_source_enum"] | null
          title: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          exercises?: Json
          id?: string
          scheduled_days?: number[] | null
          session_size?: string
          source?: Database["public"]["Enums"]["workout_source_enum"] | null
          title: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          description?: string | null
          exercises?: Json
          id?: string
          scheduled_days?: number[] | null
          session_size?: string
          source?: Database["public"]["Enums"]["workout_source_enum"] | null
          title?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "workout_plans_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      workout_sessions: {
        Row: {
          completed_at: string | null
          current_streak: number
          id: string
          longest_streak: number
          newly_unlocked_achievements: Json
          plan_exercises: Json
          points_earned: number
          session_size: string
          started_at: string
          user_id: string
          weekly_score: number
          workout_log_id: string | null
          workout_plan_id: string | null
        }
        Insert: {
          completed_at?: string | null
          current_streak?: number
          id?: string
          longest_streak?: number
          newly_unlocked_achievements?: Json
          plan_exercises?: Json
          points_earned?: number
          session_size?: string
          started_at?: string
          user_id: string
          weekly_score?: number
          workout_log_id?: string | null
          workout_plan_id?: string | null
        }
        Update: {
          completed_at?: string | null
          current_streak?: number
          id?: string
          longest_streak?: number
          newly_unlocked_achievements?: Json
          plan_exercises?: Json
          points_earned?: number
          session_size?: string
          started_at?: string
          user_id?: string
          weekly_score?: number
          workout_log_id?: string | null
          workout_plan_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "workout_sessions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workout_sessions_workout_log_id_fkey"
            columns: ["workout_log_id"]
            isOneToOne: false
            referencedRelation: "workout_logs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workout_sessions_workout_plan_id_fkey"
            columns: ["workout_plan_id"]
            isOneToOne: false
            referencedRelation: "workout_plans"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      assert_accepted_friends: {
        Args: { p_friend_ids: string[] }
        Returns: undefined
      }
      award_streak_milestone_points: {
        Args: { p_workout_log_id: string }
        Returns: {
          bonus_points: number
          points_total: number
          streak_days: number
        }[]
      }
      award_workout_points: {
        Args: { p_workout_log_id: string }
        Returns: {
          current_streak: number
          longest_streak: number
          points_earned: number
          points_total: number
        }[]
      }
      bloom_accept_child_account_link: {
        Args: { p_token: string }
        Returns: string
      }
      bloom_accept_child_invite: { Args: { p_token: string }; Returns: string }
      bloom_accept_competition_friend_invite: {
        Args: { p_id: string }
        Returns: string
      }
      bloom_accept_competition_link: {
        Args: { p_token: string }
        Returns: string
      }
      bloom_advance_account_deletion_job: {
        Args: {
          p_job_id: string
          p_removed_paths?: string[]
          p_session_id?: string
          p_step: string
        }
        Returns: Json
      }
      bloom_apply_task_breakdown: {
        Args: { p_request_id: string; p_steps: Json; p_task_id: string }
        Returns: string[]
      }
      bloom_approve_competition_child: {
        Args: { p_approve: boolean; p_child_id: string; p_id: string }
        Returns: undefined
      }
      bloom_authorize_child_provisioning: {
        Args: { p_profile_id: string }
        Returns: string
      }
      bloom_begin_coach_request: {
        Args: { p_kind: string; p_prompt: string; p_request_id: string }
        Returns: Json
      }
      bloom_begin_delete_growth_document: {
        Args: { p_document_id: string }
        Returns: Json
      }
      bloom_begin_document_help_request: {
        Args: { p_document_id: string; p_prompt: string; p_request_id: string }
        Returns: Json
      }
      bloom_begin_growth_ai_request: {
        Args: {
          p_item_id: string
          p_kind: string
          p_module_id: string
          p_prompt: string
          p_request_id: string
        }
        Returns: Json
      }
      bloom_begin_mock_exam_assessment: {
        Args: { p_answers: Json; p_exam_id: string; p_request_id: string }
        Returns: Json
      }
      bloom_begin_read_reflection_request: {
        Args: { p_item_id: string; p_request_id: string }
        Returns: Json
      }
      bloom_begin_study_tutor_request: {
        Args: { p_item_id: string; p_prompt: string; p_request_id: string }
        Returns: Json
      }
      bloom_cancel_growth_session: {
        Args: { p_session_id: string }
        Returns: undefined
      }
      bloom_cancel_workout: {
        Args: { p_session_id: string }
        Returns: undefined
      }
      bloom_change_study_occurrence: {
        Args: {
          p_action: string
          p_item_id: string
          p_moved_to_date?: string
          p_original_date: string
        }
        Returns: undefined
      }
      bloom_child_coach_proposals: {
        Args: { p_child_id: string }
        Returns: {
          created_at: string
          id: string
          profile_id: string
          proposal: Json
          status: string
        }[]
      }
      bloom_child_coaching_status: {
        Args: { p_child_id: string }
        Returns: Json
      }
      bloom_child_module_assignments: {
        Args: { p_child_profile_id: string }
        Returns: {
          assigned: boolean
          module_id: string
          updated_at: string
          updated_by: string
        }[]
      }
      bloom_clear_coach_conversation: { Args: never; Returns: undefined }
      bloom_clear_study_tutor_conversation: { Args: never; Returns: undefined }
      bloom_competition_results: {
        Args: { p_id: string }
        Returns: {
          display_name: string
          is_self: boolean
          placement: number
          score: number
          winner: boolean
        }[]
      }
      bloom_complete_workout: {
        Args: { p_results: Json; p_session_id: string }
        Returns: {
          credits_enabled: boolean
          session_id: string
        }[]
      }
      bloom_confirm_growth_document: {
        Args: { p_document_id: string }
        Returns: Json
      }
      bloom_consume_child_pairing_code: {
        Args: { p_hash: string }
        Returns: string
      }
      bloom_create_child_account_link: {
        Args: { p_profile_id: string }
        Returns: string
      }
      bloom_create_child_invite: {
        Args: { p_household_id: string }
        Returns: string
      }
      bloom_create_child_pairing_code: {
        Args: { p_profile_id: string }
        Returns: string
      }
      bloom_create_child_profile: {
        Args: { p_household_id: string; p_name: string; p_request_id: string }
        Returns: string
      }
      bloom_create_competition: {
        Args: {
          p_description: string
          p_ends: string
          p_max: number
          p_metric: string
          p_starts: string
          p_title: string
          p_visibility: string
        }
        Returns: string
      }
      bloom_create_competition_link: { Args: { p_id: string }; Returns: string }
      bloom_create_custom_exercise: {
        Args: { p_description: string; p_measurement: string; p_name: string }
        Returns: string
      }
      bloom_create_growth_child: {
        Args: {
          p_due_date: string
          p_item_type: string
          p_notes: string
          p_parent_id: string
          p_request_id: string
          p_title: string
        }
        Returns: string
      }
      bloom_create_growth_document: {
        Args: {
          p_byte_size: number
          p_file_name: string
          p_format: string
          p_item_id: string
          p_mime_type: string
          p_module_id: string
          p_request_id: string
          p_title: string
        }
        Returns: Json
      }
      bloom_create_growth_item: {
        Args: {
          p_due_date: string
          p_item_type: string
          p_module_id: string
          p_notes: string
          p_request_id: string
          p_target_minutes: number
          p_title: string
        }
        Returns: string
      }
      bloom_create_growth_project: {
        Args: {
          p_due_date: string
          p_notes: string
          p_request_id: string
          p_title: string
        }
        Returns: string
      }
      bloom_create_household: { Args: { p_name: string }; Returns: string }
      bloom_create_plan_for_user: {
        Args: { p_exercises: Json; p_title: string; p_user_id: string }
        Returns: string
      }
      bloom_create_plan_for_user_scheduled: {
        Args: {
          p_exercises: Json
          p_scheduled_days: number[]
          p_title: string
          p_user_id: string
        }
        Returns: string
      }
      bloom_create_workout_plan: {
        Args: { p_exercises: Json; p_title: string }
        Returns: string
      }
      bloom_create_workout_plan_scheduled: {
        Args: { p_exercises: Json; p_scheduled_days: number[]; p_title: string }
        Returns: string
      }
      bloom_credit_balance: { Args: never; Returns: number }
      bloom_current_profile: { Args: never; Returns: Json }
      bloom_decide_coach_proposal: {
        Args: { p_approve: boolean; p_proposal_id: string }
        Returns: string
      }
      bloom_delete_growth_document: {
        Args: { p_document_id: string }
        Returns: string
      }
      bloom_delete_growth_memory: { Args: never; Returns: undefined }
      bloom_delete_growth_record: {
        Args: { p_record_id: string }
        Returns: undefined
      }
      bloom_delete_unpaired_child_profile: {
        Args: { p_profile_id: string }
        Returns: undefined
      }
      bloom_exercise_personal_bests: {
        Args: { p_user_id?: string }
        Returns: Json
      }
      bloom_export_my_account_data: {
        Args: { p_profile_id: string; p_user_id: string }
        Returns: Json
      }
      bloom_fail_coach_request: {
        Args: { p_request_id: string }
        Returns: undefined
      }
      bloom_fail_growth_ai_request: {
        Args: { p_request_id: string }
        Returns: undefined
      }
      bloom_family_members: {
        Args: { p_household_id: string }
        Returns: {
          display_name: string
          role: string
          user_id: string
        }[]
      }
      bloom_finish_coach_request: {
        Args: { p_proposal: Json; p_reply: string; p_request_id: string }
        Returns: undefined
      }
      bloom_finish_document_help_request: {
        Args: {
          p_answer: string
          p_citations: Json
          p_prompt: string
          p_request_id: string
          p_uncertainty: string
        }
        Returns: Json
      }
      bloom_finish_growth_ai_request: {
        Args: { p_request_id: string }
        Returns: undefined
      }
      bloom_finish_growth_session: {
        Args: { p_session_id: string }
        Returns: {
          completed_at: string
          duration_seconds: number
        }[]
      }
      bloom_finish_mock_exam_assessment: {
        Args: {
          p_assessments: Json
          p_duration_seconds: number
          p_request_id: string
        }
        Returns: Json
      }
      bloom_finish_read_reflection_request: {
        Args: { p_prompt: string; p_request_id: string; p_uncertainty: string }
        Returns: Json
      }
      bloom_finish_study_tutor_request: {
        Args: {
          p_answer: string
          p_prompt: string
          p_request_id: string
          p_uncertainty: string
        }
        Returns: Json
      }
      bloom_finish_task_focus: {
        Args: { p_cancel?: boolean; p_session_id: string }
        Returns: {
          completed_at: string
          duration_seconds: number
        }[]
      }
      bloom_finish_usage_session:
        | {
            Args: { p_device_key: string; p_session_id: string }
            Returns: undefined
          }
        | {
            Args: {
              p_device_key: string
              p_session_id: string
              p_used_ms: number
            }
            Returns: undefined
          }
      bloom_get_child_document_ai_status: {
        Args: { p_child_id: string }
        Returns: Json
      }
      bloom_get_child_growth_ai_status: {
        Args: { p_child_id: string; p_module_id: string }
        Returns: Json
      }
      bloom_growth_ai_memory_context: {
        Args: { p_module_id: string }
        Returns: Json
      }
      bloom_growth_overview: {
        Args: never
        Returns: {
          active_items: number
          average_read_progress: number
          completed_items: number
          due_today: number
          minutes_this_week: number
          module_id: string
          sessions_this_week: number
        }[]
      }
      bloom_invite_competition_friend: {
        Args: { p_friend: string; p_id: string }
        Returns: undefined
      }
      bloom_is_competition_admin: { Args: never; Returns: boolean }
      bloom_is_session_revoked: {
        Args: { p_session_id: string }
        Returns: boolean
      }
      bloom_join_public_competition: { Args: { p_id: string }; Returns: string }
      bloom_leave_or_remove_child: {
        Args: { p_child_id: string; p_household_id: string }
        Returns: undefined
      }
      bloom_list_devices: {
        Args: never
        Returns: {
          auth_session_id: string | null
          blocking_state: string
          device_id: string
          display_name: string
          first_seen_at: string
          focus_supported: boolean | null
          last_seen_at: string
          permission_state: string
          platform: string
          profile_id: string
          removed_at: string | null
          revoked_at: string | null
          selected_target_count: number | null
          status_checked_at: string
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "bloom_devices"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      bloom_list_friends: {
        Args: never
        Returns: {
          display_name: string
          id: string
          incoming: boolean
          profile_id: string
          status: string
        }[]
      }
      bloom_my_competition_badges: {
        Args: never
        Returns: {
          awarded_at: string
          competition_id: string
          title: string
        }[]
      }
      bloom_my_module_assignments: {
        Args: never
        Returns: {
          module_id: string
        }[]
      }
      bloom_parent_adjust_credit: {
        Args: {
          p_child_id: string
          p_minutes: number
          p_reason: string
          p_request_id: string
        }
        Returns: undefined
      }
      bloom_parent_child_balance: {
        Args: { p_child_id: string }
        Returns: number
      }
      bloom_parent_child_growth_activity: {
        Args: { p_child_id: string }
        Returns: {
          activity_type: string
          current_page: number
          duration_seconds: number
          id: string
          module_id: string
          occurred_at: string
          page_count: number
          progress_percent: number
          title: string
        }[]
      }
      bloom_publish_competition: { Args: { p_id: string }; Returns: undefined }
      bloom_register_device: {
        Args: {
          p_blocking_state: string
          p_device_id: string
          p_display_name: string
          p_focus_supported: boolean
          p_permission_state: string
          p_platform: string
          p_selected_target_count: number
        }
        Returns: boolean
      }
      bloom_register_parent_pin: {
        Args: { p_device_id: string; p_device_secret: string; p_pin: string }
        Returns: undefined
      }
      bloom_remove_device: { Args: { p_device_id: string }; Returns: undefined }
      bloom_remove_friend: {
        Args: { p_friendship_id: string }
        Returns: undefined
      }
      bloom_remove_parent_pin: {
        Args: { p_device_id: string }
        Returns: undefined
      }
      bloom_rename_device: {
        Args: { p_device_id: string; p_display_name: string }
        Returns: undefined
      }
      bloom_request_account_deletion: {
        Args: { p_profile_id: string; p_user_id: string }
        Returns: Json
      }
      bloom_respond_friend_request: {
        Args: { p_accept: boolean; p_friendship_id: string }
        Returns: undefined
      }
      bloom_review_growth_reward: {
        Args: { p_approve: boolean; p_event_id: string }
        Returns: number
      }
      bloom_revoke_device: { Args: { p_device_id: string }; Returns: Json }
      bloom_save_growth_memory: {
        Args: {
          p_enabled: boolean
          p_shared_domains: string[]
          p_summaries: Json
        }
        Returns: undefined
      }
      bloom_save_growth_record: {
        Args: {
          p_body: string
          p_item_id: string
          p_kind: string
          p_metadata: Json
          p_module_id: string
          p_request_id: string
          p_scheduled_at: string
          p_score: number
          p_title: string
        }
        Returns: string
      }
      bloom_save_growth_reward_rules: {
        Args: {
          p_daily_cap_minutes: number
          p_enabled: boolean
          p_minimum_session_minutes: number
          p_module_id: string
          p_profile_id: string
          p_require_parent_approval: boolean
          p_reward_minutes: number
          p_weekly_cap_minutes: number
        }
        Returns: undefined
      }
      bloom_save_study_plan: { Args: { p_entries: Json }; Returns: undefined }
      bloom_save_study_verification: {
        Args: {
          p_body: string
          p_document_id: string
          p_item_id: string
          p_request_id: string
          p_title: string
        }
        Returns: string
      }
      bloom_save_weekly_earning_cap: {
        Args: { p_profile_id: string; p_weekly_cap_minutes: number }
        Returns: undefined
      }
      bloom_save_weekly_pillar_goals: {
        Args: { p_goals: Json }
        Returns: undefined
      }
      bloom_search_people: {
        Args: { p_query: string }
        Returns: {
          display_name: string
          profile_id: string
        }[]
      }
      bloom_send_friend_request: { Args: { p_other: string }; Returns: string }
      bloom_set_child_coaching: {
        Args: {
          p_child_id: string
          p_consent: boolean
          p_eligible: boolean
          p_enabled: boolean
        }
        Returns: undefined
      }
      bloom_set_child_document_ai_preferences: {
        Args: {
          p_child_id: string
          p_consent: boolean
          p_eligible: boolean
          p_enabled: boolean
        }
        Returns: undefined
      }
      bloom_set_child_growth_ai_preferences: {
        Args: {
          p_child_id: string
          p_consent: boolean
          p_eligible: boolean
          p_enabled: boolean
          p_module_id: string
        }
        Returns: undefined
      }
      bloom_set_child_module_assignments: {
        Args: { p_child_profile_id: string; p_module_ids: string[] }
        Returns: {
          assigned: boolean
          module_id: string
          updated_at: string
          updated_by: string
        }[]
      }
      bloom_set_child_search: {
        Args: { p_child_id: string; p_enabled: boolean }
        Returns: undefined
      }
      bloom_set_coach_preferences: {
        Args: {
          p_adult_attested: boolean
          p_consent: boolean
          p_equipment: string[]
          p_experience: string
          p_goals: string
        }
        Returns: undefined
      }
      bloom_set_document_ai_consent: {
        Args: { p_adult_attested: boolean; p_consent: boolean }
        Returns: undefined
      }
      bloom_set_growth_ai_preferences: {
        Args: {
          p_adult_attested: boolean
          p_consent: boolean
          p_module_id: string
        }
        Returns: undefined
      }
      bloom_set_social_profile: {
        Args: { p_name: string; p_searchable: boolean }
        Returns: undefined
      }
      bloom_set_study_subject_artwork: {
        Args: {
          p_artwork_id: string
          p_item_id: string
          p_only_if_unset?: boolean
        }
        Returns: string
      }
      bloom_set_workout_timer: {
        Args: { p_running: boolean; p_session_id: string }
        Returns: undefined
      }
      bloom_start_credit_session: {
        Args: { p_minutes: number; p_request_id: string }
        Returns: {
          session_ends_at: string
          session_id: string
          session_started_at: string
        }[]
      }
      bloom_start_enforced_credit_session: {
        Args: { p_device_key: string; p_minutes: number; p_request_id: string }
        Returns: {
          remaining_ms: number
          session_id: string
        }[]
      }
      bloom_start_growth_session: {
        Args: {
          p_item_id: string
          p_module_id: string
          p_request_id: string
          p_source_device_id: string
          p_source_device_name: string
        }
        Returns: string
      }
      bloom_start_task_focus: {
        Args: { p_request_id: string; p_task_id: string }
        Returns: string
      }
      bloom_start_usage_session: {
        Args: {
          p_device_key: string
          p_request_id: string
          p_requested_ms: number
        }
        Returns: {
          expiry_remaining_ms: number
          reserved_ms: number
          session_id: string
        }[]
      }
      bloom_start_workout: {
        Args: { p_plan_id: string }
        Returns: {
          session_id: string
          session_started_at: string
        }[]
      }
      bloom_stop_credit_session: {
        Args: { p_session_id: string }
        Returns: undefined
      }
      bloom_submit_mock_exam_objective: {
        Args: {
          p_answers: Json
          p_duration_seconds: number
          p_exam_id: string
          p_request_id: string
        }
        Returns: Json
      }
      bloom_submit_study_review: {
        Args: {
          p_next_days: number
          p_prompt_id: string
          p_rating: string
          p_request_id: string
          p_response: string
        }
        Returns: string
      }
      bloom_sync_offline_growth_session: {
        Args: {
          p_activity_id: string
          p_completed_at: string
          p_duration_seconds: number
          p_item_id: string
          p_module_id: string
          p_source_device_id: string
          p_source_device_name: string
          p_started_at: string
        }
        Returns: Json
      }
      bloom_sync_offline_task_completion: {
        Args: { p_activity_id: string; p_item_id: string }
        Returns: Json
      }
      bloom_sync_offline_workout: {
        Args: {
          p_activity_id: string
          p_completed_at: string
          p_duration_seconds: number
          p_plan_id: string
          p_results: Json
          p_started_at: string
        }
        Returns: Json
      }
      bloom_update_growth_item: {
        Args: {
          p_due_date: string
          p_item_id: string
          p_notes: string
          p_progress_percent: number
          p_state: string
          p_title: string
        }
        Returns: undefined
      }
      bloom_update_growth_record: {
        Args: {
          p_body: string
          p_metadata: Json
          p_record_id: string
          p_title: string
        }
        Returns: undefined
      }
      bloom_update_plan_for_user: {
        Args: {
          p_exercises: Json
          p_plan_id: string
          p_title: string
          p_user_id: string
        }
        Returns: string
      }
      bloom_update_plan_for_user_scheduled: {
        Args: {
          p_exercises: Json
          p_plan_id: string
          p_scheduled_days: number[]
          p_title: string
          p_user_id: string
        }
        Returns: string
      }
      bloom_update_public_competition_draft: {
        Args: {
          p_description: string
          p_ends: string
          p_id: string
          p_max: number
          p_metric: string
          p_starts: string
          p_title: string
        }
        Returns: undefined
      }
      bloom_update_reading_details: {
        Args: {
          p_author: string
          p_current_page: number
          p_genre: string
          p_item_id: string
          p_page_count: number
          p_reading_status: string
        }
        Returns: undefined
      }
      bloom_update_reading_details_v2: {
        Args: {
          p_author: string
          p_current_page: number
          p_genre: string
          p_item_id: string
          p_page_count: number
          p_reading_kind?: string
          p_reading_status: string
        }
        Returns: undefined
      }
      bloom_update_study_verification: {
        Args: {
          p_body: string
          p_document_id: string
          p_record_id: string
          p_title: string
        }
        Returns: undefined
      }
      bloom_update_task_metadata: {
        Args: {
          p_item_id: string
          p_postponed_until: string
          p_priority: string
        }
        Returns: undefined
      }
      bloom_update_workout_plan: {
        Args: { p_exercises: Json; p_plan_id: string; p_title: string }
        Returns: string
      }
      bloom_update_workout_plan_scheduled: {
        Args: {
          p_exercises: Json
          p_plan_id: string
          p_scheduled_days: number[]
          p_title: string
        }
        Returns: string
      }
      bloom_upsert_reader_position: {
        Args: { p_body: string; p_document_id: string; p_title: string }
        Returns: string
      }
      bloom_verify_countdown_grant: {
        Args: { p_device_key: string; p_request_id: string }
        Returns: {
          remaining_ms: number
          request_id: string
          session_id: string
        }[]
      }
      bloom_verify_parent_pin: {
        Args: {
          p_child_id: string
          p_device_id: string
          p_device_secret: string
          p_pin: string
        }
        Returns: string
      }
      bloom_verify_usage_grant: {
        Args: { p_device_key: string; p_session_id: string }
        Returns: {
          expiry_remaining_ms: number
          reserved_ms: number
          session_id: string
        }[]
      }
      bloom_weekly_pillar_actuals: {
        Args: never
        Returns: {
          actual_value: number
          module_id: string
        }[]
      }
      bloom_weekly_plan_progress: {
        Args: { p_user_id?: string }
        Returns: Json
      }
      bloom_workout_analytics: { Args: { p_user_id?: string }; Returns: Json }
      can_access_leaderboard: {
        Args: { p_leaderboard_id: string; p_user_id: string }
        Returns: boolean
      }
      complete_workout_session: {
        Args: {
          p_completed_exercises: Json
          p_notes?: string
          p_session_id: string
        }
        Returns: {
          current_streak: number
          earned_screen_time_minutes: number
          longest_streak: number
          newly_unlocked_achievements: Json
          points_earned: number
          points_total: number
          weekly_score: number
          workout_log_id: string
        }[]
      }
      consume_screen_time_minute: {
        Args: never
        Returns: {
          balance_minutes: number
          minutes_changed: number
        }[]
      }
      create_leaderboard_with_members: {
        Args: { p_friend_ids?: string[]; p_invite_code: string; p_name: string }
        Returns: {
          created_at: string | null
          id: string
          invite_code: string
          is_active: boolean | null
          name: string
          owner_id: string
        }
        SetofOptions: {
          from: "*"
          to: "leaderboards"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      credit_weekly_free_screen_time: {
        Args: never
        Returns: {
          balance_minutes: number
          minutes_changed: number
        }[]
      }
      evaluate_user_achievements: {
        Args: never
        Returns: {
          achievement_code: string
          achievement_name: string
          unlocked_achievement_id: string
          unlocked_reward_amount: number
          unlocked_reward_type: string
        }[]
      }
      finalize_and_reset_weekly_leaderboards: {
        Args: never
        Returns: undefined
      }
      find_active_leaderboard_by_invite: {
        Args: { p_invite_code: string }
        Returns: {
          created_at: string | null
          id: string
          invite_code: string
          is_active: boolean | null
          name: string
          owner_id: string
        }[]
        SetofOptions: {
          from: "*"
          to: "leaderboards"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_public_profile: {
        Args: { p_user_id: string }
        Returns: {
          first_name: string
          id: string
          last_name: string
          streak_count: number
          username: string
        }[]
      }
      invite_friends_to_leaderboard: {
        Args: { p_friend_ids: string[]; p_leaderboard_id: string }
        Returns: undefined
      }
      is_active_leaderboard: {
        Args: { p_leaderboard_id: string }
        Returns: boolean
      }
      is_leaderboard_member: {
        Args: { p_leaderboard_id: string; p_user_id: string }
        Returns: boolean
      }
      recalculate_my_weekly_leaderboard_score: {
        Args: never
        Returns: {
          duration_points: number
          streak_bonus: number
          total_minutes: number
          week_end: string
          week_start: string
          weekly_score: number
          workout_points: number
          workouts_count: number
        }[]
      }
      remove_friendship: {
        Args: { p_friendship_id: string }
        Returns: undefined
      }
      reset_expired_streaks: { Args: never; Returns: number }
      respond_to_friend_request: {
        Args: {
          p_friendship_id: string
          p_status: Database["public"]["Enums"]["friendship_status_enum"]
        }
        Returns: {
          addressee_id: string
          created_at: string | null
          id: string
          requester_id: string
          status: Database["public"]["Enums"]["friendship_status_enum"] | null
          updated_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "friendships"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      search_public_profiles: {
        Args: { p_limit?: number; p_query: string }
        Returns: {
          first_name: string
          id: string
          last_name: string
          streak_count: number
          username: string
        }[]
      }
      send_friend_request: {
        Args: { p_addressee_id: string }
        Returns: {
          addressee_id: string
          created_at: string | null
          id: string
          requester_id: string
          status: Database["public"]["Enums"]["friendship_status_enum"] | null
          updated_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "friendships"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      start_workout_session: {
        Args: { p_workout_plan_id?: string }
        Returns: {
          session_id: string
          started_at: string
        }[]
      }
      uuid_generate_v1: { Args: never; Returns: string }
      uuid_generate_v1mc: { Args: never; Returns: string }
      uuid_generate_v3: {
        Args: { name: string; namespace: string }
        Returns: string
      }
      uuid_generate_v4: { Args: never; Returns: string }
      uuid_generate_v5: {
        Args: { name: string; namespace: string }
        Returns: string
      }
      uuid_nil: { Args: never; Returns: string }
      uuid_ns_dns: { Args: never; Returns: string }
      uuid_ns_oid: { Args: never; Returns: string }
      uuid_ns_url: { Args: never; Returns: string }
      uuid_ns_x500: { Args: never; Returns: string }
    }
    Enums: {
      achievement_category_enum: "workout" | "streak" | "social" | "milestone"
      achievement_criteria_enum:
        | "qualifying_workout_count"
        | "current_streak"
        | "leaderboard_join"
        | "weekly_leaderboard_win"
      exercise_measurement_enum:
        | "reps_weight"
        | "time_distance"
        | "time_only"
        | "reps_only"
      friendship_status_enum: "pending" | "accepted" | "rejected"
      item_type_enum: "app" | "website"
      media_type_enum: "image" | "video" | "document"
      notification_status_enum: "unread" | "read" | "archived"
      point_reason_enum:
        | "workout_completion"
        | "streak_bonus"
        | "achievement_bonus"
        | "manual_adjustment"
      reward_type_enum: "recognition" | "points" | "screen_time"
      rule_status_enum: "active" | "inactive" | "archived"
      subscription_tier_enum: "free" | "vip"
      transaction_type_enum:
        | "earned"
        | "spent"
        | "penalty"
        | "manual_adjustment"
      user_status_enum:
        | "active"
        | "verified"
        | "onboarded"
        | "inactive"
        | "deleted"
        | "suspended"
      workout_source_enum: "manual" | "ai_generated"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      achievement_category_enum: ["workout", "streak", "social", "milestone"],
      achievement_criteria_enum: [
        "qualifying_workout_count",
        "current_streak",
        "leaderboard_join",
        "weekly_leaderboard_win",
      ],
      exercise_measurement_enum: [
        "reps_weight",
        "time_distance",
        "time_only",
        "reps_only",
      ],
      friendship_status_enum: ["pending", "accepted", "rejected"],
      item_type_enum: ["app", "website"],
      media_type_enum: ["image", "video", "document"],
      notification_status_enum: ["unread", "read", "archived"],
      point_reason_enum: [
        "workout_completion",
        "streak_bonus",
        "achievement_bonus",
        "manual_adjustment",
      ],
      reward_type_enum: ["recognition", "points", "screen_time"],
      rule_status_enum: ["active", "inactive", "archived"],
      subscription_tier_enum: ["free", "vip"],
      transaction_type_enum: [
        "earned",
        "spent",
        "penalty",
        "manual_adjustment",
      ],
      user_status_enum: [
        "active",
        "verified",
        "onboarded",
        "inactive",
        "deleted",
        "suspended",
      ],
      workout_source_enum: ["manual", "ai_generated"],
    },
  },
} as const

