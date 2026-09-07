<template>
  <nav aria-label="Breadcrumb" v-if="crumbs.length > 0">
    <ol class="ts-breadcrumbs">
      <li v-for="(crumb, index) in crumbs" :key="crumb.href + index">
        <a v-if="index < crumbs.length - 1" :href="crumb.href">{{ crumb.name }}</a>
        <span v-else aria-current="page">{{ crumb.name }}</span>
        <span v-if="index < crumbs.length - 1" aria-hidden="true"> / </span>
      </li>
    </ol>
  </nav>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useData, useRoute, withBase } from "vitepress";

interface Crumb {
  name: string;
  href: string;
}

function titleCase(part: string): string {
  return part
    .split("-")
    .map((s) => (s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s))
    .join(" ");
}

const crumbs = computed<Crumb[]>(() => {
  const route = useRoute();
  const { site } = useData();
  const base = site.value.base.replace(/\/$/, "") || "/";
  const withoutBase =
    base !== "/" && route.path.startsWith(base) ? route.path.slice(base.length) || "/" : route.path;
  const isIndex = withoutBase.endsWith("/");
  const clean = withoutBase.replace(/\.html$/, "").replace(/\/$/, "");
  const result: Crumb[] = [{ name: "Home", href: withBase("/") }];
  if (clean.length === 0 || clean === "/") return result;
  const parts = clean.split("/").filter((p) => p.length > 0);
  parts.forEach((part, index) => {
    const isLast = index === parts.length - 1;
    const joined = parts.slice(0, index + 1).join("/");
    const href = isLast && !isIndex ? withBase(`/${joined}.html`) : withBase(`/${joined}/`);
    result.push({ name: titleCase(part), href });
  });
  return result;
});
</script>
