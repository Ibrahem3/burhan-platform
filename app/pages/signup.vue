<script setup lang="ts">
definePageMeta({
  title: 'Sign Up',
})

const supabase = useSupabaseClient()
const { t } = useI18n()

const step = ref<'account' | 'org'>('account')
const loading = ref(false)
const error = ref('')

const account = reactive({
  fullName: '',
  email: '',
  password: '',
  confirmPassword: '',
})

const org = reactive({
  name: '',
  slug: '',
})

function sanitizeSlug(value: string) {
  return value.toLowerCase().replace(/[^a-z0-9-]/g, '').replace(/-+/g, '-').replace(/^-|-$/g, '')
}

function generateSlug(name: string) {
  return sanitizeSlug(name.replace(/\s+/g, '-'))
}

watch(() => org.name, (val) => {
  if (!org.slug || org.slug === sanitizeSlug(org.name)) {
    org.slug = generateSlug(val)
  }
})

function validateAccount(): boolean {
  if (!account.fullName || !account.email || !account.password) {
    error.value = 'Please fill in all fields'
    return false
  }
  if (account.password !== account.confirmPassword) {
    error.value = t('auth.password_mismatch')
    return false
  }
  if (account.password.length < 6) {
    error.value = 'Password must be at least 6 characters'
    return false
  }
  return true
}

function validateOrg(): boolean {
  if (!org.name) {
    error.value = 'Organization name is required'
    return false
  }
  if (!org.slug || org.slug.length < 2) {
    error.value = t('auth.org_slug_format')
    return false
  }
  return true
}

function proceedToOrg() {
  error.value = ''
  if (validateAccount()) {
    step.value = 'org'
  }
}

function goBack() {
  error.value = ''
  step.value = 'account'
}

async function handleSignup() {
  error.value = ''
  if (!validateOrg()) return

  loading.value = true

  try {
    const { data, error: signupError } = await supabase.auth.signUp({
      email: account.email,
      password: account.password,
      options: {
        data: {
          full_name: account.fullName,
        },
      },
    })

    if (signupError) {
      error.value = t('auth.signup_error')
      return
    }

    if (!data.session) {
      error.value = t('auth.signup_success')
      return
    }

    const { org: createdOrg } = await $fetch('/api/auth/register-tenant', {
      method: 'POST',
      body: {
        accessToken: data.session.access_token,
        orgName: org.name,
        orgSlug: org.slug,
      },
    })

    await navigateTo(`/${createdOrg.org_slug}`)
  } catch (err: any) {
    if (err?.statusCode === 409) {
      error.value = t('auth.org_slug_taken')
    } else {
      error.value = t('auth.org_create_error')
    }
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-[calc(100vh-4rem)] flex items-center justify-center px-4 py-12">
    <div class="absolute inset-0 overflow-hidden pointer-events-none">
      <div class="absolute top-1/4 -right-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-3xl" />
      <div class="absolute bottom-1/4 -left-40 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
    </div>

    <div class="relative w-full max-w-md">
      <GlassCard padding="lg">
        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold gradient-gold mb-2">{{ $t('auth.create_account') }}</h1>
          <p class="text-sm text-gray-500">{{ step === 'account' ? $t('brand.tagline') : $t('auth.org_setup_desc') }}</p>
        </div>

        <!-- Step indicator -->
        <div class="flex items-center justify-center gap-2 mb-8">
          <div
            class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all duration-300"
            :class="step === 'account' ? 'bg-gold text-onyx' : 'bg-gold/20 text-gold'"
          >1</div>
          <div class="w-8 h-0.5 rounded" :class="step === 'org' ? 'bg-gold/60' : 'bg-white/10'" />
          <div
            class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all duration-300"
            :class="step === 'org' ? 'bg-gold text-onyx' : 'bg-white/10 text-gray-500'"
          >2</div>
        </div>

        <!-- Step 1: Account -->
        <form v-if="step === 'account'" novalidate @submit.prevent="proceedToOrg">
          <div class="space-y-4">
            <div>
              <label for="name" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.full_name_label') }}
              </label>
              <input
                id="name"
                v-model="account.fullName"
                type="text"
                autocomplete="name"
                :placeholder="$t('auth.full_name_placeholder')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
              />
            </div>

            <div>
              <label for="email" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.email') }}
              </label>
              <input
                id="email"
                v-model="account.email"
                type="email"
                autocomplete="email"
                :placeholder="$t('auth.email_placeholder')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                required
              />
            </div>

            <div>
              <label for="password" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.password') }}
              </label>
              <input
                id="password"
                v-model="account.password"
                type="password"
                autocomplete="new-password"
                :placeholder="$t('auth.password_placeholder')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                required
              />
            </div>

            <div>
              <label for="confirm" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.confirm_password') }}
              </label>
              <input
                id="confirm"
                v-model="account.confirmPassword"
                type="password"
                autocomplete="new-password"
                :placeholder="$t('auth.confirm_password')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                required
              />
            </div>

            <div v-if="error" class="text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
              {{ error }}
            </div>

            <Button type="submit" block>
              {{ $t('common.next') }}
            </Button>
          </div>
        </form>

        <!-- Step 2: Organization -->
        <form v-else novalidate @submit.prevent="handleSignup">
          <div class="space-y-4">
            <div>
              <label for="org-name" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.org_name') }}
              </label>
              <input
                id="org-name"
                v-model="org.name"
                type="text"
                :placeholder="$t('auth.org_name_placeholder')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                :disabled="loading"
                required
              />
            </div>

            <div>
              <label for="org-slug" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.org_slug') }}
              </label>
              <div class="relative">
                <span class="absolute inset-y-0 left-4 flex items-center text-xs text-gray-600 pointer-events-none" dir="ltr">/</span>
                <input
                  id="org-slug"
                  v-model="org.slug"
                  type="text"
                  :placeholder="$t('auth.org_slug_placeholder')"
                  class="w-full px-4 py-2.5 pl-7 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 font-mono text-sm focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                  :disabled="loading"
                  dir="ltr"
                  required
                  @input="org.slug = sanitizeSlug(org.slug)"
                />
              </div>
              <p class="text-xs text-gray-600 mt-1.5">{{ $t('auth.org_slug_format') }}</p>
            </div>

            <div v-if="error" class="text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
              {{ error }}
            </div>

            <div class="flex gap-3">
              <Button variant="outline" :disabled="loading" @click="goBack">
                {{ $t('common.previous') }}
              </Button>
              <Button type="submit" block :loading="loading">
                {{ $t('auth.signup_btn') }}
              </Button>
            </div>
          </div>
        </form>

        <div class="mt-6 text-center">
          <p class="text-sm text-gray-500">
            {{ $t('auth.has_account') }}
            <NuxtLink to="/login" class="text-gold hover:text-gold-500 transition-colors font-medium">
              {{ $t('auth.login_btn') }}
            </NuxtLink>
          </p>
        </div>
      </GlassCard>
    </div>
  </div>
</template>
