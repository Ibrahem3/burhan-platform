<script setup lang="ts">
definePageMeta({
  title: 'Login',
})

const supabase = useSupabaseClient()
const { t } = useI18n()

const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')

async function handleLogin() {
  error.value = ''
  loading.value = true

  try {
    const { error: authError } = await supabase.auth.signInWithPassword({
      email: email.value,
      password: password.value,
    })

    if (authError) {
      error.value = t('auth.login_error')
      return
    }

    await navigateTo('/')
  } catch {
    error.value = t('auth.login_error')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-[calc(100vh-4rem)] flex items-center justify-center px-4 py-12">
    <div class="absolute inset-0 overflow-hidden pointer-events-none">
      <div class="absolute top-1/3 -left-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-3xl" />
      <div class="absolute bottom-1/3 -right-40 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
    </div>

    <div class="relative w-full max-w-md">
      <GlassCard padding="lg">
        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold gradient-gold mb-2">{{ $t('auth.welcome_back') }}</h1>
          <p class="text-sm text-gray-500">{{ $t('brand.tagline') }}</p>
        </div>

        <form novalidate @submit.prevent="handleLogin">
          <div class="space-y-5">
            <div>
              <label for="email" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.email') }}
              </label>
              <input
                id="email"
                v-model="email"
                type="email"
                autocomplete="email"
                :placeholder="$t('auth.email_placeholder')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                :disabled="loading"
                required
              />
            </div>

            <div>
              <label for="password" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.password') }}
              </label>
              <input
                id="password"
                v-model="password"
                type="password"
                autocomplete="current-password"
                :placeholder="$t('auth.password_placeholder')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                :disabled="loading"
                required
              />
            </div>

            <div v-if="error" class="text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
              {{ error }}
            </div>

            <Button type="submit" block :loading="loading">
              {{ $t('auth.login_btn') }}
            </Button>
          </div>
        </form>

        <div class="mt-6 text-center">
          <p class="text-sm text-gray-500">
            {{ $t('auth.no_account') }}
            <NuxtLink to="/signup" class="text-gold hover:text-gold-500 transition-colors font-medium">
              {{ $t('auth.signup_btn') }}
            </NuxtLink>
          </p>
        </div>
      </GlassCard>
    </div>
  </div>
</template>
