<script setup lang="ts">
interface Props {
  isPremium: boolean
  price?: number | null
  entityTitle?: string | null
}

withDefaults(defineProps<Props>(), {
  price: null,
  entityTitle: null,
})

const { isAuthenticated, isOrgStaff, user } = useUser()
const { locale } = useI18n()

const formattedPrice = computed(() => {
  if (!props.price) return null
  return new Intl.NumberFormat(locale.value === 'ar' ? 'ar-SA' : 'en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(props.price)
})

const isAccessible = computed(() => {
  if (!props.isPremium) return true
  if (isOrgStaff.value) return true
  return false
})

const locked = computed(() => props.isPremium && !isAccessible.value)
</script>

<template>
  <div class="relative">
    <Transition name="fade" mode="out-in">
      <!-- Content accessible -->
      <div v-if="!locked" key="content">
        <slot />
      </div>

      <!-- Locked premium overlay -->
      <div v-else key="locked" class="relative">
        <!-- Blurred preview of content -->
        <div class="pointer-events-none select-none blur-sm opacity-30">
          <slot />
        </div>

        <!-- Lock overlay -->
        <div class="absolute inset-0 flex items-center justify-center p-6">
          <GlassCard class="text-center max-w-lg w-full mx-auto gold-border">
            <div class="flex flex-col items-center gap-4 py-4">
              <!-- Premium badge -->
              <Badge variant="premium" size="md">
                <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
                {{ $t('premium.badge') }}
              </Badge>

              <!-- Lock icon -->
              <div class="w-16 h-16 rounded-full bg-gold/10 border border-gold/20 flex items-center justify-center">
                <svg class="w-8 h-8 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </div>

              <!-- Title & description -->
              <div class="space-y-2">
                <h3 class="text-xl font-bold text-white">
                  {{ $t('premium.lock_title') }}
                </h3>
                <p class="text-sm text-gray-400 max-w-sm mx-auto">
                  {{ $t('premium.lock_description') }}
                </p>
              </div>

              <!-- Price tag -->
              <div v-if="formattedPrice" class="flex items-center gap-2 px-4 py-2 rounded-xl bg-gold/5 border border-gold/10">
                <span class="text-xs text-gray-500">{{ $t('entities.price') }}:</span>
                <span class="text-lg font-bold text-gold">{{ formattedPrice }}</span>
              </div>

              <!-- CTA -->
              <Button v-if="isAuthenticated" size="lg" class="w-full max-w-xs">
                {{ $t('entities.purchase') }}
              </Button>
              <NuxtLink v-else to="/signup" class="w-full max-w-xs">
                <Button size="lg" block>
                  {{ $t('premium.cta') }}
                </Button>
              </NuxtLink>

              <!-- Learn more -->
              <NuxtLink to="/premium" class="text-xs text-gray-500 hover:text-gold transition-colors">
                {{ $t('premium.learn_more') }}
              </NuxtLink>
            </div>
          </GlassCard>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.35s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
