export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type ModuleType = 'content' | 'forum' | 'media'
export type UserRole = 'super_admin' | 'owner' | 'manager' | 'member'

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
          video_id: string | null
          primary_source: string
          fallback_source: string | null
          fallback_url: string | null
          is_premium: boolean
          price: number | null
          created_at: string
        }
        Insert: {
          id?: string
          branch_id: string
          organization_id: string
          title: Json
          content?: Json
          is_public_to_hub?: boolean
          video_id?: string | null
          primary_source?: string
          fallback_source?: string | null
          fallback_url?: string | null
          is_premium?: boolean
          price?: number | null
          created_at?: string
        }
        Update: {
          id?: string
          branch_id?: string
          organization_id?: string
          title?: Json
          content?: Json
          is_public_to_hub?: boolean
          video_id?: string | null
          primary_source?: string
          fallback_source?: string | null
          fallback_url?: string | null
          is_premium?: boolean
          price?: number | null
          created_at?: string
        }
      }
    }
    Views: Record<string, never>
    Functions: Record<string, never>
    Enums: {
      module_type: ModuleType
      user_role: UserRole
    }
  }
}
