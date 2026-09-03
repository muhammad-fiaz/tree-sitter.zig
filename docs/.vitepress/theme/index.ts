import type { Theme } from "vitepress";
import DefaultTheme from "vitepress/theme";
import "./custom.css";
import ApiCard from "./components/ApiCard.vue";
import ExampleCard from "./components/ExampleCard.vue";
import ExampleOutput from "./components/ExampleOutput.vue";
import CodeTabs from "./components/CodeTabs.vue";
import FeatureGrid from "./components/FeatureGrid.vue";
import VersionBadge from "./components/VersionBadge.vue";
import CompatibilityTable from "./components/CompatibilityTable.vue";
import MemoryModel from "./components/MemoryModel.vue";
import DocBreadcrumbs from "./components/DocBreadcrumbs.vue";
import AdSlot from "./components/AdSlot.vue";
import DocsLayout from "./layouts/DocsLayout.vue";
import { trackPageView } from "../analytics/google-analytics";

export default {
  extends: DefaultTheme,
  Layout: DocsLayout,
  enhanceApp({ app, router }) {
    app.component("ApiCard", ApiCard);
    app.component("ExampleCard", ExampleCard);
    app.component("ExampleOutput", ExampleOutput);
    app.component("CodeTabs", CodeTabs);
    app.component("FeatureGrid", FeatureGrid);
    app.component("VersionBadge", VersionBadge);
    app.component("CompatibilityTable", CompatibilityTable);
    app.component("MemoryModel", MemoryModel);
    app.component("DocBreadcrumbs", DocBreadcrumbs);
    app.component("AdSlot", AdSlot);
    if (typeof window !== "undefined" && router) {
      router.onAfterRouteChange = (to: string) => trackPageView(to);
    }
  },
} satisfies Theme;
