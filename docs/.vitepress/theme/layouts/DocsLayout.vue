<template>
  <Layout>
    <template #doc-before>
      <DocBreadcrumbs />
    </template>
    <template #doc-after>
      <AdSlot slot="bottom-content" />
    </template>
  </Layout>
</template>

<script setup lang="ts">
import DefaultTheme from "vitepress/theme";
import DocBreadcrumbs from "../components/DocBreadcrumbs.vue";
import AdSlot from "../components/AdSlot.vue";

const Layout = DefaultTheme.Layout;
</script>
