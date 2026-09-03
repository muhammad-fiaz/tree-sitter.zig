<template>
  <div v-if="isEnabled" class="ts-ad" aria-label="Advertisement">
    <ins
      class="adsbygoogle"
      style="display: block"
      data-ad-client="ca-pub-2040560600290490"
      :data-ad-slot="slot"
      data-ad-format="auto"
      data-full-width-responsive="true"
    ></ins>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from "vue";
import { ADSENSE_ENABLED, pushAdSlot } from "../../analytics/adsense";

const props = withDefaults(defineProps<{ slot: string; enabled?: boolean }>(), { enabled: true });
const isEnabled = computed(() => ADSENSE_ENABLED && props.enabled);

onMounted(() => {
  pushAdSlot();
});
</script>
