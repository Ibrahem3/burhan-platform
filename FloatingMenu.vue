<script setup lang="ts">
import { 
  LayoutDashboard, Store, ShoppingBag, Settings, ChevronLeft, ChevronRight,
  Lightbulb, ShoppingCart, Award, MessageSquare, Bell, Map, Search, Pin,
  LogOut, Globe, Languages, Menu, X, Sparkles
} from 'lucide-vue-next';

const tenantStore = useTenantStore();
const featuresStore = useFeaturesStore();
const { locale, t, setLocale } = useI18n();
const route = useRoute();
const supabase = useSupabaseClient();
const router = useRouter();
const { branding } = useAdminContext();

// UI State from AdminUI Composable
const { isMobileMenuOpen, isPinned, togglePin } = useAdminUI();

const isHovered = ref(false);

// 🛡️ Bulletproof Branch Slug Extraction
const branchSlug = computed(() => {
    if (route.params.slug) return route.params.slug;
    const pathParts = route.path.split('/');
    if (route.path.startsWith('/staff/admin/') && pathParts.length >= 4) {
        try { return decodeURIComponent(pathParts[3]); } catch(e) { return pathParts[3]; }
    }
    return tenantStore.currentBranchSlug || '';
});
const basePath = computed(() => branchSlug.value ? `/staff/admin/${branchSlug.value}` : '/staff/admin');

// 🛠️ Smart Menu Structure (Computed for reactivity with i18n)
const menuStructure = computed(() => {
  const base = basePath.value;
  return [
  {
    group: t('dashboard.sidebar.groups.overview'),
    items: [
      { id: 'dashboard', label: t('dashboard.sidebar.home'), to: base, icon: LayoutDashboard },
    ]
  },
  {
    group: t('dashboard.sidebar.groups.commerce'),
    items: [
      { id: 'orders', label: t('dashboard.sidebar.orders'), to: `${base}/orders`, icon: ShoppingCart },
      { id: 'products', label: t('dashboard.sidebar.store'), to: `${base}/shop/products`, icon: ShoppingBag },
    ]
  },
  {
    group: t('dashboard.sidebar.groups.creative'),
    items: [
      { id: 'portfolio', label: t('dashboard.sidebar.portfolio'), to: `${base}/portfolio`, icon: Award },
      { id: 'tips', label: t('dashboard.sidebar.tips'), to: `${base}/tips`, icon: Lightbulb },
    ]
  },
  {
    group: t('dashboard.sidebar.groups.reputation'),
    items: [
      { id: 'reviews', label: t('dashboard.sidebar.reviews'), to: `${base}/reviews`, icon: MessageSquare },
      { id: 'services', label: t('dashboard.sidebar.services'), to: `${base}/services`, icon: Store },
    ]
  },
  {
    group: t('dashboard.sidebar.groups.settings'),
    items: [
      { id: 'identity', label: t('dashboard.sidebar.identity'), to: `${base}/settings`, icon: Settings },
      { id: 'location', label: t('dashboard.sidebar.location'), to: `${base}/settings/location`, icon: Map },
      { id: 'directory', label: t('dashboard.sidebar.directory'), to: `${base}/settings/directory`, icon: Search },
      { id: 'notifications', label: t('dashboard.sidebar.notifications'), to: `${base}/notifications`, icon: Bell },
      { id: 'feature_hub', label: t('dashboard.settings.features.title'), to: `${base}/settings/features`, icon: Sparkles },
    ]
  }
]});

// ✨ Dynamic Filtering Logic
const activeGroups = computed(() => {
  return menuStructure.value
    .map(g => ({
      ...g,
      items: g.items.filter(item => {
          if (item.id === 'dashboard' || item.id === 'identity' || item.id === 'feature_hub') return true;
          return featuresStore.isModuleActive(item.id);
      })
    }))
    .filter(g => g.items.length > 0);
});

const isExpanded = computed(() => isPinned.value || isHovered.value);
const primaryColor = computed(() => tenantStore.primaryColor);

const logout = async () => {
    await supabase.auth.signOut();
    router.push('/login');
};

const toggleLocale = () => {
    setLocale(locale.value === 'ar' ? 'en' : 'ar');
};

const storeUrl = computed(() => {
    const slug = branchSlug.value;
    if (!slug) return '/';
    
    const isLocal = process.client && (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1');
    const subdomain = tenantStore.tenant?.subdomain;

    if (isLocal) return `/${slug}`;
    return `https://${subdomain}.ainux.online/${slug}`;
});

const handleToggle = () => {
    if (window.innerWidth < 1024) {
        isMobileMenuOpen.value = !isMobileMenuOpen.value;
    }
};
</script>

<template>
  <ClientOnly>
    <!-- 🖥️/📱 Unified Hybrid Transformer Menu -->
    <div 
        class="fixed z-[120] transition-all duration-300 cubic-bezier(0.16, 1, 0.3, 1) will-change-[width,height,transform,opacity]"
        :class="[
        // Desktop: Floating or Pinned
        'lg:block',
        isExpanded ? 'lg:w-[340px] lg:h-[94vh] lg:rounded-[3rem]' : 'lg:w-16 lg:h-16 lg:rounded-full',
        
        // Mobile: Floating Bubble (Always Persistent)
        'w-14 h-14 rounded-full bottom-6 shadow-2xl lg:bottom-auto',
        
        locale === 'ar' ? 'right-6' : 'left-6',
        isPinned ? 'lg:top-[3vh] lg:translate-y-0' : 'lg:top-1/2 lg:-translate-y-1/2'
        ]"
        @mouseenter="isHovered = true"
        @mouseleave="isHovered = false"
        @click="handleToggle"
    >
        <!-- Background Container -->
        <div 
        class="w-full h-full border backdrop-blur-2xl shadow-[0_30px_60px_-12px_rgba(0,0,0,0.5)] overflow-hidden flex flex-col transition-all duration-300 border-white/10 relative"
        :class="isExpanded ? 'lg:rounded-[3rem]' : 'rounded-full'"
        :style="{ backgroundColor: 'rgba(9, 9, 11, 0.96)' }"
        @dblclick="togglePin"
        >
        <!-- 🫧 Bubble State (Single Icon) - Visible on desktop (if not expanded) and mobile (Always toggle) -->
        <Transition name="fade" mode="out-in">
            <div v-if="!isExpanded || isMobileMenuOpen" :key="isMobileMenuOpen ? 'close' : 'open'" class="absolute inset-0 flex items-center justify-center cursor-pointer">
                <div class="w-10 h-10 rounded-full flex items-center justify-center transition-all duration-300" :style="{ backgroundColor: primaryColor + '20' }">
                    <X v-if="isMobileMenuOpen" class="w-6 h-6" :style="{ color: primaryColor }" />
                    <Menu v-else class="w-5 h-5 lg:w-6 lg:h-6" :style="{ color: primaryColor }" />
                </div>
            </div>
        </Transition>

        <!-- 📑 Desktop Expanded Content -->
        <div 
            class="h-full hidden lg:flex flex-col transition-opacity duration-200"
            :class="isExpanded ? 'opacity-100' : 'opacity-0 pointer-events-none'"
        >
            <!-- Header -->
            <div class="p-8 flex items-center justify-between border-b border-white/5 shrink-0">
            <div class="flex items-center gap-4 overflow-hidden">
                <div class="w-10 h-10 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center shrink-0">
                    <img :src="branding.logo" class="w-7 h-7 object-contain" />
                </div>
                <div class="flex flex-col">
                    <span class="font-black text-sm text-white truncate max-w-[140px]">{{ branding.name }}</span>
                    <span class="text-[10px] text-gray-500 font-bold tracking-tighter uppercase">Transformer Hub</span>
                </div>
            </div>
            <button @click.stop="togglePin" class="p-2 rounded-xl hover:bg-white/5 transition-all">
                <Pin class="w-4 h-4 transition-transform duration-300" :style="{ color: isPinned ? primaryColor : '#4b5563', fill: isPinned ? primaryColor : 'transparent' }" :class="isPinned ? 'rotate-45' : ''" />
            </button>
            </div>

            <!-- Scrollable Links -->
            <div class="flex-1 overflow-y-auto px-6 py-8 scrollbar-none space-y-8">
            <div v-for="g in activeGroups" :key="g.group" class="space-y-3">
                <p class="text-[9px] font-black uppercase tracking-[0.3em] text-gray-600 px-4 mb-1">{{ g.group }}</p>
                <NuxtLink v-for="item in g.items" :key="item.id" :to="item.to" class="flex items-center gap-4 px-5 py-3.5 rounded-[1.25rem] transition-all duration-200 relative group/item" :class="route.path === item.to ? 'bg-white/5' : 'hover:bg-white/5'">
                <div v-if="route.path === item.to" class="absolute left-0 w-1.5 h-5 rounded-full" :style="{ backgroundColor: primaryColor }" ></div>
                <div class="flex items-center justify-center w-5 h-5 shrink-0 transition-all">
                  <component :is="item.icon" class="w-full h-full" :style="{ color: route.path === item.to ? primaryColor : '' }" :class="route.path === item.to ? 'scale-110' : 'text-gray-500 group-hover/item:text-white'" />
                </div>
                <span class="text-sm font-bold tracking-tight text-gray-500 group-hover/item:text-white transition-colors" :class="route.path === item.to ? 'text-white' : ''">{{ item.label }}</span>
                </NuxtLink>
            </div>
            </div>

            <!-- Footer Actions -->
            <div class="p-6 border-t border-white/5 space-y-3 shrink-0">
            <div class="grid grid-cols-2 gap-2">
                <button @click.stop="toggleLocale" class="flex items-center justify-center gap-2 py-3 rounded-2xl bg-white/5 text-gray-400 hover:text-white transition-all text-[10px] font-black uppercase">
                <Languages class="w-4 h-4" /> {{ locale === 'ar' ? 'EN' : 'AR' }}
                </button>
                <a :href="storeUrl" target="_blank" class="flex items-center justify-center gap-2 py-3 rounded-2xl bg-blue-500/10 text-blue-500 hover:text-blue-400 transition-all text-[10px] font-black uppercase">
                    <Globe class="w-4 h-4" /> {{ t('dashboard.sidebar.visit_site') }}
                </a>
            </div>
            <button @click.stop="logout" class="flex items-center justify-center gap-3 py-3 w-full rounded-2xl text-red-500/80 bg-red-500/5 hover:bg-red-500/10 transition-all group">
                <LogOut class="w-4 h-4 group-hover:translate-x-1 transition-transform" />
                <span class="text-[10px] font-black uppercase tracking-widest">{{ t('dashboard.sidebar.logout') }}</span>
            </button>
            </div>
        </div>
        </div>
    </div>

    <!-- 📱 Mobile Drawer Menu -->
    <Transition :name="locale === 'ar' ? 'slide-left' : 'slide-right'">
        <div v-if="isMobileMenuOpen" class="fixed inset-y-0 z-[110] w-[85%] max-w-[320px] bg-zinc-950 border-white/10 flex flex-col lg:hidden shadow-2xl transition-all duration-300" :class="locale === 'ar' ? 'right-0' : 'left-0'">
        <div class="p-6 border-b border-white/5 flex items-center justify-between">
            <div class="flex items-center gap-3">
                <img :src="branding.logo" class="w-8 h-8 rounded-xl object-contain" />
                <span class="font-black text-sm text-white truncate max-w-[150px]">{{ branding.name }}</span>
            </div>
        </div>
        <div class="flex-1 overflow-y-auto px-4 py-6 space-y-8">
            <div v-for="g in activeGroups" :key="g.group" class="space-y-2">
            <p class="text-[10px] font-black uppercase tracking-widest text-gray-600 px-4">{{ g.group }}</p>
            <NuxtLink v-for="item in g.items" :key="item.id" :to="item.to" @click="isMobileMenuOpen = false" class="flex items-center gap-4 px-4 py-3.5 rounded-2xl transition-all" :class="route.path === item.to ? 'bg-white/10 text-white' : 'text-gray-400'">
                <component :is="item.icon" class="w-5 h-5" :style="{ color: route.path === item.to ? primaryColor : '' }" />
                <span class="text-sm font-bold">{{ item.label }}</span>
            </NuxtLink>
            </div>
        </div>
        <div class="p-4 border-t border-white/5 space-y-2 bg-black/20">
            <div class="grid grid-cols-2 gap-2">
                <button @click="toggleLocale" class="flex items-center justify-center gap-2 py-3 rounded-xl text-gray-400 bg-white/5"><Languages class="w-4 h-4" /><span class="text-xs font-bold">{{ locale === 'ar' ? 'EN' : 'AR' }}</span></button>
                <a :href="storeUrl" target="_blank" class="flex items-center justify-center gap-2 py-3 rounded-xl text-blue-500 bg-blue-500/5"><Globe class="w-4 h-4" /><span class="text-xs font-bold">{{ t('dashboard.sidebar.visit_site') }}</span></a>
            </div>
            <button @click="logout" class="flex items-center justify-center gap-3 px-4 py-3 w-full rounded-xl text-red-500/80 bg-red-500/5"><LogOut class="w-5 h-5" /><span class="text-xs font-bold uppercase">{{ t('dashboard.sidebar.logout') }}</span></button>
        </div>
        </div>
    </Transition>
  </ClientOnly>
</template>

<style scoped>
.scrollbar-none::-webkit-scrollbar { display: none; }
.scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }

.fade-enter-active, .fade-leave-active { transition: opacity 0.2s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }

.slide-right-enter-active, .slide-right-leave-active,
.slide-left-enter-active, .slide-left-leave-active { transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1); }

.slide-right-enter-from, .slide-right-leave-to { transform: translateX(-100%); }
.slide-left-enter-from, .slide-left-leave-to { transform: translateX(100%); }
</style>
