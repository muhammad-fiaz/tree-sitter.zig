<template>
  <div class="ts-card">
    <h4><a :href="resolveSiteLink(link)" @click="onOpen">{{ title }}</a></h4>
    <p>{{ description }}</p>
    <p v-if="level">
      <span class="ts-badge">{{ level }}</span>
    </p>
    <p><a :href="resolveSiteLink(link)" @click="onOpen">Open the example →</a></p>
  </div>
</template>

<script setup lang="ts">
import { trackExampleView } from "../../analytics/google-analytics";
import { resolveSiteLink } from "../utils/siteLink";

const props = defineProps<{
  title: string;
  description: string;
  link: string;
  level?: string;
}>();

function onOpen(): void {
  trackExampleView(props.title);
}
</script>
