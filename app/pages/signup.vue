<script setup lang="ts">
definePageMeta({
  title: 'Sign Up',
})

const supabase = useSupabaseClient()
const { t } = useI18n()
const { currentLocale } = useLocale()

const step = ref<'account' | 'org' | 'verify'>('account')
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

// OTP Reactive State
const otpCode = ref('')
const resendCooldown = ref(0)
const isResending = ref(false)
const isVerifying = ref(false)
const provisioningFailed = ref(false)
const verifiedAccessToken = ref('')

let cooldownTimer: ReturnType<typeof setInterval> | null = null

function startCooldown(seconds = 60) {
  if (cooldownTimer) {
    clearInterval(cooldownTimer)
    cooldownTimer = null
  }
  resendCooldown.value = seconds
  cooldownTimer = setInterval(() => {
    if (resendCooldown.value > 0) {
      resendCooldown.value--
    } else {
      if (cooldownTimer) {
        clearInterval(cooldownTimer)
        cooldownTimer = null
      }
    }
  }, 1000)
}

onUnmounted(() => {
  if (cooldownTimer) {
    clearInterval(cooldownTimer)
    cooldownTimer = null
  }
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
  if (account.password.length < 7) {
    error.value = t('auth.password_min_length')
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

function changeEmail() {
  error.value = ''
  // Security boundary: wipe password and OTP state on return to account step
  account.password = ''
  account.confirmPassword = ''
  otpCode.value = ''
  verifiedAccessToken.value = ''
  provisioningFailed.value = false
  if (cooldownTimer) {
    clearInterval(cooldownTimer)
    cooldownTimer = null
  }
  resendCooldown.value = 0
  step.value = 'account'
}

async function provisionTenant(accessToken: string) {
  loading.value = true
  provisioningFailed.value = false
  error.value = ''

  try {
    const res = await $fetch<{ org: { org_slug: string } }>('/api/auth/register-tenant', {
      method: 'POST',
      body: {
        accessToken,
        orgName: org.name,
        orgSlug: org.slug,
      },
    })

    // Wipe sensitive in-memory state before navigating away
    otpCode.value = ''
    verifiedAccessToken.value = ''
    provisioningFailed.value = false

    await navigateTo('/dashboard')
  } catch (err: any) {
    provisioningFailed.value = true
    verifiedAccessToken.value = accessToken // Keep token strictly in memory for retry
    if (err?.statusCode === 409) {
      if (err?.data?.code === 'user_already_has_tenant') {
        error.value = t('auth.user_already_has_tenant', 'User already owns an organization')
      } else {
        error.value = t('auth.org_slug_taken')
      }
    } else {
      error.value = t('auth.provisioning_failed')
    }
  } finally {
    loading.value = false
  }
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
      const code = signupError.code || ''
      const msg = signupError.message || ''
      const status = signupError.status || 0

      if (code === 'weak_password' || status === 422 || msg.toLowerCase().includes('weak_password')) {
        error.value = t('auth.weak_password')
      } else if (code === 'over_email_send_rate_limit' || status === 429) {
        error.value = t('auth.rate_limited')
      } else if (code === 'user_already_exists' || msg.toLowerCase().includes('already registered')) {
        error.value = t('auth.signup_error')
      } else {
        error.value = t('auth.signup_error')
      }
      return
    }

    if (data?.session?.access_token) {
      // Direct session granted (email confirmation disabled)
      await provisionTenant(data.session.access_token)
      return
    }

    // Email Confirmation required
    // Security: wipe passwords from memory before entering OTP step
    account.password = ''
    account.confirmPassword = ''

    otpCode.value = ''
    startCooldown(60)
    step.value = 'verify'
  } catch (err: any) {
    error.value = t('auth.signup_error')
  } finally {
    loading.value = false
  }
}

async function handleVerifyOtp() {
  error.value = ''
  const trimmed = otpCode.value.trim()

  if (!/^\d{6}$/.test(trimmed)) {
    error.value = t('auth.invalid_otp')
    return
  }

  isVerifying.value = true

  try {
    const { data, error: otpError } = await supabase.auth.verifyOtp({
      email: account.email,
      token: trimmed,
      type: 'signup',
    })

    if (otpError) {
      const code = otpError.code || ''
      const msg = otpError.message || ''
      const status = otpError.status || 0

      if (code === 'otp_expired' || msg.toLowerCase().includes('expired')) {
        error.value = t('auth.expired_otp')
      } else if (code === 'over_email_send_rate_limit' || status === 429) {
        error.value = t('auth.rate_limited')
      } else if (code === 'otp_invalid' || code === 'bad_code' || msg.toLowerCase().includes('invalid')) {
        error.value = t('auth.invalid_otp')
      } else {
        error.value = t('auth.invalid_otp')
      }
      return
    }

    const accessToken = data?.session?.access_token
    if (!accessToken) {
      error.value = t('auth.provisioning_failed')
      return
    }

    await provisionTenant(accessToken)
  } catch (err: any) {
    error.value = t('auth.provisioning_failed')
  } finally {
    isVerifying.value = false
  }
}

async function handleResendOtp() {
  if (resendCooldown.value > 0 || isResending.value) return

  error.value = ''
  isResending.value = true

  try {
    const { error: resendErr } = await supabase.auth.resend({
      type: 'signup',
      email: account.email,
    })

    if (resendErr) {
      const code = resendErr.code || ''
      const status = resendErr.status || 0
      if (code === 'over_email_send_rate_limit' || status === 429) {
        error.value = t('auth.rate_limited')
      } else {
        error.value = t('auth.invalid_otp')
      }
      return
    }

    otpCode.value = ''
    startCooldown(60)
  } catch {
    error.value = t('auth.invalid_otp')
  } finally {
    isResending.value = false
  }
}
</script>

<template>
  <div class="min-h-[calc(100vh-4rem)] flex items-center justify-center px-4 py-8 sm:py-12 relative overflow-hidden">
    <!-- Ambient Background Auras -->
    <div class="absolute inset-0 overflow-hidden pointer-events-none">
      <div class="absolute top-1/4 -right-40 w-[600px] h-[600px] bg-gold/10 rounded-full blur-[140px]" />
      <div class="absolute bottom-1/4 -left-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-[140px]" />
      <div class="absolute inset-0 bg-[linear-gradient(to_right,#ffffff03_1px,transparent_1px),linear-gradient(to_bottom,#ffffff03_1px,transparent_1px)] bg-[size:3.5rem_3.5rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_50%,#000_70%,transparent_100%)]" />
    </div>

    <!-- Main Container: Dual-Panel Showcase on Desktop, Single Focused Card on Mobile -->
    <div class="relative w-full max-w-5xl grid grid-cols-1 lg:grid-cols-12 gap-8 items-center z-10">
      
      <!-- Left Column: Sovereign Architecture Showcase (Visible on Large Screens) -->
      <div class="hidden lg:flex lg:col-span-5 flex-col justify-between space-y-8 p-6">
        <div>
          <!-- Brand Badge -->
          <div class="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full glass bg-white/[0.03] border border-white/10 shadow-sm mb-6">
            <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            <span class="text-xs text-gold font-mono uppercase tracking-wider">Burhan Cloud v2.0</span>
          </div>

          <h1 class="text-3xl xl:text-4xl font-extrabold text-white tracking-tight leading-tight mb-4">
            {{ currentLocale === 'ar' ? 'منصتك المعرفية المستقلة تبدأ من هنا' : 'Your Sovereign Knowledge Hub Starts Here' }}
          </h1>

          <p class="text-sm text-gray-400 leading-relaxed">
            {{ currentLocale === 'ar' 
              ? 'صممت منظومة برهان للمراكز العلمية والجهات الفكرية التي تطلب أعلى درجات العزل المؤسسي، وإدارة السلاسل، والتأمين الشامل للبيانات.'
              : 'Engineered for intellectual centers requiring strict multi-tenant isolation, structured learning series, and enterprise cryptographic boundaries.'
            }}
          </p>
        </div>

        <!-- 3 Feature Pillars -->
        <div class="space-y-4 pt-4 border-t border-white/5">
          <div class="flex items-start gap-3.5">
            <div class="w-9 h-9 rounded-xl bg-gold/10 border border-gold/20 flex items-center justify-center shrink-0 text-gold text-sm font-bold">
              🏛️
            </div>
            <div>
              <p class="text-xs font-bold text-white">{{ currentLocale === 'ar' ? 'عزل بيانات سيادي تام' : 'Sovereign Multi-Tenancy' }}</p>
              <p class="text-[11px] text-gray-400 mt-0.5">{{ currentLocale === 'ar' ? 'قاعدة بيانات مستقلة الصلاحيات وسياسات RLS مؤمّنة' : 'Database-level Row Level Security and complete tenant segregation' }}</p>
            </div>
          </div>

          <div class="flex items-start gap-3.5">
            <div class="w-9 h-9 rounded-xl bg-gold/10 border border-gold/20 flex items-center justify-center shrink-0 text-gold text-sm font-bold">
              ⚡
            </div>
            <div>
              <p class="text-xs font-bold text-white">{{ currentLocale === 'ar' ? 'تجهيز فوري ومسار آلي' : 'Instant Atomic Provisioning' }}</p>
              <p class="text-[11px] text-gray-400 mt-0.5">{{ currentLocale === 'ar' ? 'تجهيز الفرع والمكتبة وتوثيق الهوية لحظياً بعد OTP' : 'Zero-delay branch setup, schema allocation, and onboarding' }}</p>
            </div>
          </div>

          <div class="flex items-start gap-3.5">
            <div class="w-9 h-9 rounded-xl bg-gold/10 border border-gold/20 flex items-center justify-center shrink-0 text-gold text-sm font-bold">
              🛡️
            </div>
            <div>
              <p class="text-xs font-bold text-white">{{ currentLocale === 'ar' ? 'ذكاء اصطناعي مشفر BYOK' : 'Zero-Knowledge Encrypted AI' }}</p>
              <p class="text-[11px] text-gray-400 mt-0.5">{{ currentLocale === 'ar' ? 'تشفير AES-256-GCM للمفاتيح وحماية كاملة ضد SSRF' : 'AES-256-GCM encrypted credentials with strict egress validation' }}</p>
            </div>
          </div>
        </div>

        <!-- Trust footer line -->
        <div class="pt-4 border-t border-white/5 flex items-center gap-2 text-xs text-gray-500 font-mono">
          <span class="w-1.5 h-1.5 rounded-full bg-emerald-500" />
          <span>{{ currentLocale === 'ar' ? 'نظام التسجيل الذري مؤمّن ومراقب' : 'Atomic Registration Gateway Protected' }}</span>
        </div>
      </div>

      <!-- Right Column: The Interactive Glass Form (Single Container) -->
      <div class="lg:col-span-7 w-full max-w-lg mx-auto">
        <div
          class="relative rounded-3xl border border-white/10 p-6 sm:p-9 shadow-2xl shadow-black/80 flex flex-col"
          style="background: rgba(14, 14, 14, 0.88); backdrop-filter: blur(28px); box-shadow: inset 0 1px 0 rgba(255,255,255,0.06);"
        >
          <!-- Card Header -->
          <div class="text-center mb-6">
            <h2 class="text-2xl sm:text-3xl font-bold gradient-gold mb-1.5 tracking-tight">
              {{ step === 'verify' ? $t('auth.otp_title') : $t('auth.create_account') }}
            </h2>
            <p class="text-xs sm:text-sm text-gray-400">
              {{
                step === 'account'
                  ? $t('brand.tagline')
                  : step === 'org'
                    ? $t('auth.org_setup_desc')
                    : $t('auth.otp_desc', { email: account.email })
              }}
            </p>
          </div>

          <!-- Step Progress Ribbon -->
          <div class="mb-7 pb-5 border-b border-white/5">
            <div class="grid grid-cols-3 gap-2 text-center">
              <!-- Step 1 -->
              <div class="flex flex-col items-center gap-1.5">
                <div
                  class="w-8 h-8 rounded-xl flex items-center justify-center text-xs font-bold transition-all duration-300 shadow-sm"
                  :class="step === 'account' ? 'bg-gold text-onyx shadow-gold/20 scale-105' : 'bg-gold/15 text-gold border border-gold/30'"
                >
                  <span v-if="step !== 'account'">✓</span>
                  <span v-else>1</span>
                </div>
                <span class="text-[10px] sm:text-[11px] font-medium transition-colors" :class="step === 'account' ? 'text-gold' : 'text-gray-400'">
                  {{ currentLocale === 'ar' ? 'الحساب' : 'Account' }}
                </span>
              </div>

              <!-- Step 2 -->
              <div class="flex flex-col items-center gap-1.5">
                <div
                  class="w-8 h-8 rounded-xl flex items-center justify-center text-xs font-bold transition-all duration-300 shadow-sm"
                  :class="step === 'org' ? 'bg-gold text-onyx shadow-gold/20 scale-105' : step === 'verify' ? 'bg-gold/15 text-gold border border-gold/30' : 'bg-white/5 text-gray-500 border border-white/5'"
                >
                  <span v-if="step === 'verify'">✓</span>
                  <span v-else>2</span>
                </div>
                <span class="text-[10px] sm:text-[11px] font-medium transition-colors" :class="step === 'org' ? 'text-gold' : 'text-gray-400'">
                  {{ currentLocale === 'ar' ? 'المنظمة' : 'Organization' }}
                </span>
              </div>

              <!-- Step 3 -->
              <div class="flex flex-col items-center gap-1.5">
                <div
                  class="w-8 h-8 rounded-xl flex items-center justify-center text-xs font-bold transition-all duration-300 shadow-sm"
                  :class="step === 'verify' ? 'bg-gold text-onyx shadow-gold/20 scale-105' : 'bg-white/5 text-gray-500 border border-white/5'"
                >
                  3
                </div>
                <span class="text-[10px] sm:text-[11px] font-medium transition-colors" :class="step === 'verify' ? 'text-gold' : 'text-gray-400'">
                  {{ currentLocale === 'ar' ? 'التحقق' : 'Verify OTP' }}
                </span>
              </div>
            </div>
          </div>

          <!-- Step 1: Account Form -->
          <form v-if="step === 'account'" novalidate @submit.prevent="proceedToOrg">
            <div class="space-y-4">
              <div>
                <label for="name" class="block text-xs font-semibold text-gray-300 mb-1.5">
                  {{ $t('auth.full_name_label') }}
                </label>
                <div class="relative">
                  <span class="absolute inset-y-0 start-3.5 flex items-center text-gray-500 pointer-events-none">
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                  </span>
                  <input
                    id="name"
                    v-model="account.fullName"
                    type="text"
                    autocomplete="name"
                    :placeholder="$t('auth.full_name_placeholder')"
                    class="w-full ps-10 pe-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 text-xs sm:text-sm transition-all"
                  />
                </div>
              </div>

              <div>
                <label for="email" class="block text-xs font-semibold text-gray-300 mb-1.5">
                  {{ $t('auth.email') }}
                </label>
                <div class="relative">
                  <span class="absolute inset-y-0 start-3.5 flex items-center text-gray-500 pointer-events-none">
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                    </svg>
                  </span>
                  <input
                    id="email"
                    v-model="account.email"
                    type="email"
                    autocomplete="email"
                    :placeholder="$t('auth.email_placeholder')"
                    class="w-full ps-10 pe-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 text-xs sm:text-sm transition-all"
                    required
                  />
                </div>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label for="password" class="block text-xs font-semibold text-gray-300 mb-1.5">
                    {{ $t('auth.password') }}
                  </label>
                  <div class="relative">
                    <span class="absolute inset-y-0 start-3.5 flex items-center text-gray-500 pointer-events-none">
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                      </svg>
                    </span>
                    <input
                      id="password"
                      v-model="account.password"
                      type="password"
                      autocomplete="new-password"
                      :placeholder="$t('auth.password_placeholder')"
                      class="w-full ps-10 pe-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 text-xs sm:text-sm transition-all"
                      required
                    />
                  </div>
                </div>

                <div>
                  <label for="confirm" class="block text-xs font-semibold text-gray-300 mb-1.5">
                    {{ $t('auth.confirm_password') }}
                  </label>
                  <div class="relative">
                    <span class="absolute inset-y-0 start-3.5 flex items-center text-gray-500 pointer-events-none">
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                      </svg>
                    </span>
                    <input
                      id="confirm"
                      v-model="account.confirmPassword"
                      type="password"
                      autocomplete="new-password"
                      :placeholder="$t('auth.confirm_password')"
                      class="w-full ps-10 pe-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 text-xs sm:text-sm transition-all"
                      required
                    />
                  </div>
                </div>
              </div>

              <div v-if="error" class="text-red-400 text-xs text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
                {{ error }}
              </div>

              <Button type="submit" block class="h-11 text-sm font-bold shadow-lg shadow-gold/20">
                {{ $t('common.next') }}
              </Button>
            </div>
          </form>

          <!-- Step 2: Organization Form -->
          <form v-else-if="step === 'org'" novalidate @submit.prevent="handleSignup">
            <div class="space-y-4">
              <div>
                <label for="org-name" class="block text-xs font-semibold text-gray-300 mb-1.5">
                  {{ $t('auth.org_name') }}
                </label>
                <div class="relative">
                  <span class="absolute inset-y-0 start-3.5 flex items-center text-gray-500 pointer-events-none">
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                    </svg>
                  </span>
                  <input
                    id="org-name"
                    v-model="org.name"
                    type="text"
                    :placeholder="$t('auth.org_name_placeholder')"
                    class="w-full ps-10 pe-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 text-xs sm:text-sm transition-all"
                    :disabled="loading"
                    required
                  />
                </div>
              </div>

              <div>
                <label for="org-slug" class="block text-xs font-semibold text-gray-300 mb-1.5">
                  {{ $t('auth.org_slug') }}
                </label>
                <div class="relative">
                  <span class="absolute inset-y-0 left-3.5 flex items-center text-xs font-mono text-gray-500 pointer-events-none" dir="ltr">/</span>
                  <input
                    id="org-slug"
                    v-model="org.slug"
                    type="text"
                    :placeholder="$t('auth.org_slug_placeholder')"
                    class="w-full px-4 py-2.5 pl-7 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 font-mono text-xs sm:text-sm focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all"
                    :disabled="loading"
                    dir="ltr"
                    required
                    @input="org.slug = sanitizeSlug(org.slug)"
                  />
                </div>
                
                <!-- Live Subdomain URL Preview -->
                <div class="mt-2 p-2 rounded-lg bg-white/[0.02] border border-white/5 flex items-center gap-1.5 text-[11px] font-mono text-gray-400" dir="ltr">
                  <span class="text-gray-600">URL:</span>
                  <span class="text-gold">https://burhan.ainux.online/<span class="text-white font-bold">{{ org.slug || 'your-slug' }}</span></span>
                </div>
                <p class="text-[11px] text-gray-500 mt-1">{{ $t('auth.org_slug_format') }}</p>
              </div>

              <div v-if="error" class="text-red-400 text-xs text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
                {{ error }}
              </div>

              <div class="flex gap-3 pt-2">
                <Button variant="outline" :disabled="loading" class="w-1/3 h-11" @click="goBack">
                  {{ $t('common.previous') }}
                </Button>
                <Button type="submit" block :loading="loading" class="flex-1 h-11 text-sm font-bold shadow-lg shadow-gold/20">
                  {{ $t('auth.signup_btn') }}
                </Button>
              </div>
            </div>
          </form>

          <!-- Step 3: Verify OTP Form -->
          <div v-else-if="step === 'verify'" class="space-y-5">
            <div class="p-3.5 bg-white/5 border border-white/10 rounded-2xl text-center">
              <span class="text-xs text-gray-400 block mb-1">{{ $t('auth.email') }}</span>
              <span dir="ltr" class="text-sm font-mono font-bold text-gold">{{ account.email }}</span>
            </div>

            <!-- Provisioning retry state -->
            <div v-if="provisioningFailed" class="space-y-4">
              <div class="text-red-400 text-xs text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3">
                {{ error || $t('auth.provisioning_failed') }}
              </div>

              <Button
                type="button"
                block
                :loading="loading"
                class="h-11 font-bold"
                @click="provisionTenant(verifiedAccessToken)"
              >
                {{ $t('auth.retry_provisioning') }}
              </Button>
            </div>

            <!-- Normal OTP entry form -->
            <form v-else novalidate @submit.prevent="handleVerifyOtp">
              <div class="space-y-4">
                <div>
                  <label for="otp-input" class="block text-xs font-semibold text-gray-300 mb-2 text-center">
                    {{ $t('auth.otp_title') }}
                  </label>
                  <input
                    id="otp-input"
                    v-model="otpCode"
                    type="text"
                    inputmode="numeric"
                    autocomplete="one-time-code"
                    maxlength="6"
                    dir="ltr"
                    :placeholder="$t('auth.otp_placeholder')"
                    class="w-full px-4 py-3.5 bg-white/5 border border-white/10 rounded-2xl text-white placeholder-gray-600 font-mono text-2xl font-black tracking-[0.5em] text-center focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 shadow-inner transition-all"
                    :disabled="isVerifying || loading"
                    required
                    @input="otpCode = otpCode.replace(/[^0-9]/g, '').slice(0, 6)"
                  />
                </div>

                <div v-if="error" class="text-red-400 text-xs text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
                  {{ error }}
                </div>

                <Button type="submit" block :loading="isVerifying || loading" :disabled="otpCode.trim().length !== 6" class="h-11 font-bold shadow-lg shadow-gold/20">
                  {{ $t('auth.verify_btn') }}
                </Button>

                <div class="flex items-center justify-between pt-2">
                  <button
                    type="button"
                    class="text-xs text-gray-400 hover:text-white transition-colors"
                    :disabled="isVerifying || loading"
                    @click="changeEmail"
                  >
                    {{ $t('auth.change_email') }}
                  </button>

                  <button
                    type="button"
                    class="text-xs font-medium text-gold hover:text-gold-300 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    :disabled="resendCooldown > 0 || isResending || isVerifying || loading"
                    @click="handleResendOtp"
                  >
                    <span v-if="resendCooldown > 0">
                      {{ $t('auth.resend_wait', { seconds: resendCooldown }) }}
                    </span>
                    <span v-else-if="isResending">...</span>
                    <span v-else>
                      {{ $t('auth.resend_btn') }}
                    </span>
                  </button>
                </div>
              </div>
            </form>
          </div>

          <!-- Card Footer (Switch to Login) -->
          <div class="mt-6 pt-5 border-t border-white/5 text-center">
            <p class="text-xs text-gray-400">
              {{ $t('auth.has_account') }}
              <NuxtLink to="/login" class="text-gold hover:text-gold-300 transition-colors font-bold ms-1">
                {{ $t('auth.login_btn') }}
              </NuxtLink>
            </p>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>
