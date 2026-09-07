<template>
  <div class="ts-feature-grid">
    <div class="ts-card" v-for="feature in features" :key="feature.title">
      <h4>{{ feature.title }}</h4>
      <p>{{ feature.description }}</p>
      <p v-if="feature.link"><a :href="resolveSiteLink(feature.link)">Learn more →</a></p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { resolveSiteLink } from "../utils/siteLink";

defineProps<{
  features: { title: string; description: string; link?: string }[];
}>();
</script>
