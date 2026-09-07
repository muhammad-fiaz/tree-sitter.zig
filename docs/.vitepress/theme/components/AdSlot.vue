<template>
  <div v-if="isEnabled" class="ts-ad" aria-label="Advertisement">
    <ins
      class="adsbygoogle"
      style="display: block"
      :data-ad-client="ADSENSE_CLIENT_ID"
      :data-ad-slot="slot"
      data-ad-format="auto"
      data-full-width-responsive="true"
    ></ins>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from "vue";
import { ADSENSE_CLIENT_ID, ADSENSE_ENABLED, pushAdSlot } from "../../analytics/adsense";

const props = withDefaults(defineProps<{ slot: string; enabled?: boolean }>(), { enabled: true });
const isEnabled = computed(() => ADSENSE_ENABLED && props.enabled);

onMounted(() => {
  pushAdSlot();
});
</script>
