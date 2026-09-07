<template>
  <div class="ts-card">
    <h4><a :href="resolveSiteLink(link)" @click="onOpen">{{ name }}</a></h4>
    <p>{{ description }}</p>
    <p v-if="signature">
      <code>{{ signature }}</code>
    </p>
    <p v-if="link"><a :href="resolveSiteLink(link)" @click="onOpen">Read the reference →</a></p>
  </div>
</template>

<script setup lang="ts">
import { trackApiReferenceView } from "../../analytics/google-analytics";
import { resolveSiteLink } from "../utils/siteLink";

const props = defineProps<{
  name: string;
  description: string;
  link: string;
  signature?: string;
}>();

function onOpen(): void {
  trackApiReferenceView(props.name);
}
</script>
