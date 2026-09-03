<template>
  <p class="ts-badges" aria-label="Version information">
    <span class="ts-badge solid">tree-sitter.zig {{ version }}</span>
    <span class="ts-badge">Zig {{ zig }}</span>
    <span v-if="status" class="ts-badge">{{ status }}</span>
  </p>
</template>

<script setup lang="ts">
import { SITE_VERSION, ZIG_VERSION } from "../../seo/metadata";

withDefaults(
  defineProps<{ version?: string; zig?: string; status?: string }>(),
  { version: SITE_VERSION, zig: ZIG_VERSION, status: "Stable" },
);
</script>
