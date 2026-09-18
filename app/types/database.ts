export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type ModuleType = 'content' | 'forum' | 'media'
export type UserRole = 'super_admin' | 'owner' | 'manager' | 'member'
export type DangerLevel = 'Low' | 'Medium' | 'High'
export type ThreatStatus = 'pending' | 'under_review' | 'neutralized'
export type AnalystRole = 'observatory_manager' | 'observatory_analyst'
export type AiJobStatus = 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled'

export interface Database {
  public: {
    Tables: {
      organizations: {
        Row: {
          id: string
          name: string
          org_slug: string
          settings: Json
          created_at: string
        }
        Insert: {
          id?: string
          name: string
          org_slug: string
          settings?: Json
          created_at?: string
        }
        Update: {
          id?: string
          name?: string
          org_slug?: string
          settings?: Json
          created_at?: string
        }
      }
      branches: {
        Row: {
          id: string
          organization_id: string
          name: Json
          module_type: ModuleType
          slug: string
          is_active: boolean
          created_at: string
        }
        Insert: {
          id?: string
          organization_id: string
          name: Json
          module_type: ModuleType
          slug: string
          is_active?: boolean
          created_at?: string
        }
        Update: {
          id?: string
          organization_id?: string
          name?: Json
          module_type?: ModuleType
          slug?: string
          is_active?: boolean
          created_at?: string
        }
      }
      profiles: {
        Row: {
          id: string
          organization_id: string | null
          full_name: Json
          role: UserRole
          created_at: string
        }
        Insert: {
          id: string
          organization_id?: string | null
          full_name?: Json
          role?: UserRole
          created_at?: string
        }
        Update: {
          id?: string
          organization_id?: string | null
          full_name?: Json
          role?: UserRole
          created_at?: string
        }
      }
      entities: {
        Row: {
          id: string
          branch_id: string
          organization_id: string
          title: Json
          content: Json
          is_public_to_hub: boolean
          content_type: string
          video_id: string | null
          primary_source: string
          fallback_source: string | null
          fallback_url: string | null
          audio_url: string | null
          audio_file: string | null
          is_premium: boolean
          price: number | null
          series_id: string | null
          sort_order: number
          created_at: string
        }
        Insert: {
          id?: string
          branch_id: string
          organization_id: string
          title: Json
          content?: Json
          is_public_to_hub?: boolean
          content_type?: string
          video_id?: string | null
          primary_source?: string
          fallback_source?: string | null
          fallback_url?: string | null
          audio_url?: string | null
          audio_file?: string | null
          is_premium?: boolean
          price?: number | null
          series_id?: string | null
          sort_order?: number
          created_at?: string
        }
        Update: {
          id?: string
          branch_id?: string
          organization_id?: string
          title?: Json
          content?: Json
          is_public_to_hub?: boolean
          content_type?: string
          video_id?: string | null
          primary_source?: string
          fallback_source?: string | null
          fallback_url?: string | null
          audio_url?: string | null
          audio_file?: string | null
          is_premium?: boolean
          price?: number | null
          series_id?: string | null
          sort_order?: number
          created_at?: string
        }
      }
      observatory_threats: {
        Row: {
          id: string
          title: string
          source_url: string
          platform: string
          danger_level: DangerLevel
          status: ThreatStatus
          assigned_scholar_id: string | null
          reported_by: string | null
          response_url: string | null
          created_at: string
        }
        Insert: {
          id?: string
          title: string
          source_url: string
          platform?: string
          danger_level?: DangerLevel
          status?: ThreatStatus
          assigned_scholar_id?: string | null
          reported_by?: string | null
          response_url?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          title?: string
          source_url?: string
          platform?: string
          danger_level?: DangerLevel
          status?: ThreatStatus
          assigned_scholar_id?: string | null
          reported_by?: string | null
          response_url?: string | null
          created_at?: string
        }
      }
      observatory_analysts: {
        Row: {
          id: string
          role_type: AnalystRole
          created_at: string
        }
        Insert: {
          id: string
          role_type: AnalystRole
          created_at?: string
        }
        Update: {
          id?: string
          role_type?: AnalystRole
          created_at?: string
        }
      }
      ai_jobs: {
        Row: {
          id: string
          user_id: string
          organization_id: string
          branch_id: string | null
          prompt: string
          system_prompt: string | null
          language: string
          model: string | null
          status: AiJobStatus
          output_buffer: string
          output_final: string
          error: string | null
          tokens_estimated: number
          tokens_used: number
          period_month: string
          quota_reconciled: boolean
          consumed: boolean
          created_at: string
          updated_at: string
          last_heartbeat_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          organization_id: string
          branch_id?: string | null
          prompt: string
          system_prompt?: string | null
          language?: string
          model?: string | null
          status?: AiJobStatus
          output_buffer?: string
          output_final?: string
          error?: string | null
          tokens_estimated?: number
          tokens_used?: number
          period_month?: string
          quota_reconciled?: boolean
          consumed?: boolean
          created_at?: string
          updated_at?: string
          last_heartbeat_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          organization_id?: string
          branch_id?: string | null
          prompt?: string
          system_prompt?: string | null
          language?: string
          model?: string | null
          status?: AiJobStatus
          output_buffer?: string
          output_final?: string
          error?: string | null
          tokens_estimated?: number
          tokens_used?: number
          period_month?: string
          quota_reconciled?: boolean
          consumed?: boolean
          created_at?: string
          updated_at?: string
          last_heartbeat_at?: string | null
        }
      }
      ai_usage: {
        Row: {
          organization_id: string
          period_month: string
          requests_used: number
          tokens_reserved: number
          tokens_used: number
        }
        Insert: {
          organization_id: string
          period_month: string
          requests_used?: number
          tokens_reserved?: number
          tokens_used?: number
        }
        Update: {
          organization_id?: string
          period_month?: string
          requests_used?: number
          tokens_reserved?: number
          tokens_used?: number
        }
      }
    }
    Views: Record<string, never>
    Functions: {
      ai_is_super_admin: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      ai_reserve_usage: {
        Args: {
          p_user_id: string
          p_org_id: string
          p_tokens_estimated: number
          p_request_limit: number
          p_token_limit: number
        }
        Returns: {
          organization_id: string
          period_month: string
          requests_used: number
          tokens_reserved: number
        }
      }
      ai_reconcile_job: {
        Args: { p_job_id: string }
        Returns: boolean
      }
      reserve_ai_quota: {
        Args: {
          p_user_id: string
          p_org_id: string
          p_tokens_estimated: number
          p_request_limit: number
          p_token_limit: number
        }
        Returns: {
          organization_id: string
          period_month: string
          requests_used: number
          tokens_reserved: number
        }
      }
      create_ai_job: {
        Args: {
          p_user_id: string
          p_org_id: string
          p_branch_id?: string | null
          p_prompt: string
          p_system_prompt?: string | null
          p_language?: string
          p_model?: string | null
          p_tokens_estimated?: number
          p_request_limit?: number | null
          p_token_limit?: number | null
        }
        Returns: {
          id: string
          organization_id: string
          period_month: string
          status: string
        }
      }
      start_ai_job: {
        Args: { p_job_id: string; p_user_id: string; p_model?: string | null }
        Returns: {
          changed: boolean
          status?: AiJobStatus
          reason?: string
        }
      }
      heartbeat_ai_job: {
        Args: { p_job_id: string; p_user_id: string; p_output_buffer?: string | null }
        Returns: {
          changed: boolean
          status?: AiJobStatus
          reason?: string
        }
      }
      complete_ai_job: {
        Args: {
          p_job_id: string
          p_user_id: string
          p_tokens_used?: number | null
          p_output_final?: string | null
        }
        Returns: {
          changed: boolean
          status?: AiJobStatus
          reason?: string
        }
      }
      fail_ai_job: {
        Args: { p_job_id: string; p_user_id: string; p_error?: string | null }
        Returns: {
          changed: boolean
          status?: AiJobStatus
          reason?: string
        }
      }
      cancel_ai_job: {
        Args: { p_job_id: string; p_user_id: string }
        Returns: {
          changed: boolean
          status?: AiJobStatus
          reason?: string
        }
      }
      consume_ai_job: {
        Args: { p_job_id: string; p_user_id: string }
        Returns: {
          changed: boolean
          consumed: boolean
        }
      }
      reap_stale_ai_job: {
        Args: { p_job_id: string; p_stale_after_seconds?: number }
        Returns: {
          changed: boolean
          status?: AiJobStatus
          reason?: string
        }
      }
      reconcile_abandoned_terminal_ai_jobs: {
        Args: { p_job_id?: string | null }
        Returns: { reconciled: number }
      }
    }
    Enums: {
      module_type: ModuleType
      user_role: UserRole
    }
  }
}
