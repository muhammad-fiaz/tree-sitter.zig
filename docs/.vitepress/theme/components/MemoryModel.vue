<template>
  <div class="ts-memory-flow" role="list" aria-label="Memory ownership flow">
    <template v-for="(step, index) in steps" :key="step">
      <div class="step" role="listitem">{{ step }}</div>
      <div v-if="index < steps.length - 1" class="arrow" aria-hidden="true">↓</div>
    </template>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{ steps?: string[] }>(),
  {
    steps: () => [
      "Client owns an allocator (e.g. std.heap.DebugAllocator)",
      "Parser.init(allocator) borrows it for the parser lifetime",
      "parseString copies source bytes into the new Tree",
      "Tree owns its node pool, child index buffer, and source copy",
      "tree.cursor() / parser.queryCursor() inherit the stored allocator",
      "Every deinit releases exactly what its object owns",
    ],
  },
);
</script>
