<template>
  <div class="ts-table-wrap">
    <table>
      <caption v-if="caption">{{ caption }}</caption>
      <thead>
        <tr>
          <th scope="col">Platform</th>
          <th scope="col">Architectures</th>
          <th scope="col">Status</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="row.platform">
          <th scope="row">{{ row.platform }}</th>
          <td>{{ row.arches }}</td>
          <td>{{ row.status }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    caption?: string;
    rows?: { platform: string; arches: string; status: string }[];
  }>(),
  {
    caption: "Validated build targets (Zig 0.16.0)",
    rows: () => [
      { platform: "Windows", arches: "x86, x86_64, ARM64", status: "Supported" },
      { platform: "Linux", arches: "x86, x86_64, ARM64", status: "Supported" },
      { platform: "macOS", arches: "x86_64, ARM64", status: "Supported" },
    ],
  },
);
</script>
