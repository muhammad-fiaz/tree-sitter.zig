<template>
  <div class="ts-output" role="region" :aria-label="title">
    <div class="ts-output-title">{{ title }}</div>
    <slot />
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{ title?: string }>(), { title: "Expected output" });
</script>
