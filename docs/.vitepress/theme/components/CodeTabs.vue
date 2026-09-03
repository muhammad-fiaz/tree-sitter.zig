<template>
  <div class="ts-code-tabs">
    <div class="tabs" role="tablist" :aria-label="label">
      <button
        v-for="(tab, index) in tabs"
        :key="tab.label"
        role="tab"
        :aria-selected="active === index"
        @click="active = index"
      >
        {{ tab.label }}
      </button>
    </div>
    <div role="tabpanel">
      <slot :name="`tab-${active}`" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue";

withDefaults(
  defineProps<{
    label?: string;
    tabs: { label: string }[];
  }>(),
  { label: "Code examples" },
);

const active = ref(0);
</script>
