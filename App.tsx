import React, { useEffect } from "react";
import { AppState } from "react-native";
// Defines the background task that follows GitHub jobs while the app is closed (must load at start-up).
import "./services/backgroundJobs";
import { checkJobs } from "./services/jobs";
import { View, Text, Pressable, StyleSheet } from "react-native";
import { NavigationContainer, DarkTheme } from "@react-navigation/native";
import { createBottomTabNavigator, BottomTabBarProps } from "@react-navigation/bottom-tabs";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { SafeAreaProvider, useSafeAreaInsets } from "react-native-safe-area-context";
import { StatusBar } from "expo-status-bar";
import { LinearGradient } from "expo-linear-gradient";
import { Ionicons } from "./components/icons";
import Backdrop from "./components/Backdrop";

import HomeScreen from "./screens/HomeScreen";
import AppsScreen from "./screens/AppsScreen";
import SettingsScreen from "./screens/SettingsScreen";
import CreateScreen from "./screens/CreateScreen";
import AppDetailScreen from "./screens/AppDetailScreen";
import PreviewScreen from "./screens/PreviewScreen";
import InstantPreviewScreen from "./screens/InstantPreviewScreen";
import ChatScreen from "./screens/ChatScreen";
import GalleryScreen from "./screens/GalleryScreen";
import PairScreen from "./screens/PairScreen";
import UpdateScreen from "./screens/UpdateScreen";
import { colors, gradient, space } from "./theme";
import ErrorBoundary from "./components/ErrorBoundary";
import type { RootStackParamList } from "./navigation";

const Stack = createNativeStackNavigator<RootStackParamList>();

// Every screen sits on an opaque navy base with the glass backdrop behind it. The base keeps each stack screen opaque
// (so a screen never shows the one under it during a transition); the screen's own root is transparent.
function withBackdrop<P extends object>(Screen: React.ComponentType<P>) {
  const Wrapped = (props: P) => (
    <View style={{ flex: 1, backgroundColor: colors.base }}>
      <Backdrop />
      <Screen {...props} />
    </View>
  );
  Wrapped.displayName = `Glass(${Screen.displayName || Screen.name || "Screen"})`;
  return Wrapped;
}

const S = {
  Home: withBackdrop(HomeScreen),
  Apps: withBackdrop(AppsScreen),
  Settings: withBackdrop(SettingsScreen),
  Create: withBackdrop(CreateScreen),
  AppDetail: withBackdrop(AppDetailScreen),
  Preview: withBackdrop(PreviewScreen),
  InstantPreview: withBackdrop(InstantPreviewScreen),
  Chat: withBackdrop(ChatScreen),
  Gallery: withBackdrop(GalleryScreen),
  Pair: withBackdrop(PairScreen),
  Update: withBackdrop(UpdateScreen),
};
const Tab = createBottomTabNavigator();

const navTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    primary: colors.primary,
    background: colors.base,
    card: colors.glassBar,
    text: colors.text,
    border: colors.border,
  },
};

type IconName = React.ComponentProps<typeof Ionicons>["name"];

// Dock slots, right to left. A slot is a tab of this navigator, or (Gallery) a screen pushed on the root stack.
const DOCK: { key: string; label: string; icon: IconName; tab?: string; push?: keyof RootStackParamList }[] = [
  { key: "Home", label: "الرئيسية", icon: "home", tab: "Home" },
  { key: "Apps", label: "تطبيقاتي", icon: "apps", tab: "Apps" },
  { key: "new", label: "", icon: "add" },
  { key: "Gallery", label: "المعرض", icon: "color-palette", push: "Gallery" },
  { key: "Settings", label: "الإعدادات", icon: "settings", tab: "Settings" },
];

/** Bottom dock: a full-width glass bar with four labelled slots and a raised gradient "new app" button in the middle. */
function TabBar({ state, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const current = state.routes[state.index]?.name;
  return (
    <View style={styles.dockWrap} pointerEvents="box-none">
      <View style={[styles.dock, { paddingBottom: Math.max(insets.bottom, 10) }]}>
        {DOCK.map((d) => {
          if (d.key === "new") {
            return (
              <View key="new" style={styles.slot} pointerEvents="box-none">
                <Pressable
                  onPress={() => navigation.getParent()?.navigate("Create")}
                  style={({ pressed }) => [styles.fab, pressed && { transform: [{ scale: 0.92 }] }]}
                  accessibilityRole="button"
                  accessibilityLabel="تطبيق جديد"
                >
                  <LinearGradient colors={gradient as unknown as string[]} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={[StyleSheet.absoluteFill, { borderRadius: 999 }]} />
                  <Ionicons name="add" size={32} color={colors.primaryText} />
                </Pressable>
              </View>
            );
          }
          const focused = !!d.tab && d.tab === current;
          return (
            <Pressable
              key={d.key}
              onPress={() => {
                if (d.push) {
                  navigation.getParent()?.navigate(d.push as never);
                  return;
                }
                const route = state.routes.find((r) => r.name === d.tab)!;
                const e = navigation.emit({ type: "tabPress", target: route.key, canPreventDefault: true });
                if (!focused && !e.defaultPrevented) navigation.navigate(d.tab!);
              }}
              style={styles.slot}
              accessibilityRole={d.tab ? "tab" : "button"}
              accessibilityState={{ selected: focused }}
              accessibilityLabel={d.label}
            >
              <View style={[styles.slotIcon, focused && styles.slotIconOn]}>
                {focused ? (
                  <LinearGradient colors={gradient as unknown as string[]} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={[StyleSheet.absoluteFill, { borderRadius: 14 }]} />
                ) : null}
                <Ionicons name={d.icon} size={21} color={focused ? colors.primaryText : colors.textMuted} />
              </View>
              <Text style={[styles.slotLabel, focused && styles.slotLabelOn]}>{d.label}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

function Tabs() {
  return (
    <Tab.Navigator tabBar={(p) => <TabBar {...p} />} screenOptions={{ headerShown: false }}>
      <Tab.Screen name="Home" component={S.Home} />
      <Tab.Screen name="Apps" component={S.Apps} />
      <Tab.Screen name="Settings" component={S.Settings} />
    </Tab.Navigator>
  );
}

export default function App() {
  // Jobs that ended while APK Fact was closed: notify / clean up now, and again each time the app comes back.
  useEffect(() => {
    checkJobs();
    const sub = AppState.addEventListener("change", (s) => s === "active" && checkJobs());
    return () => sub.remove();
  }, []);
  return (
    <SafeAreaProvider>
      <View style={{ flex: 1, backgroundColor: colors.base }}>
        <ErrorBoundary>
          <NavigationContainer theme={navTheme}>
            <StatusBar style="light" />
            <Stack.Navigator screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.base } }}>
              <Stack.Screen name="Tabs" component={Tabs} />
              <Stack.Screen name="AppDetail" component={S.AppDetail} options={{ animation: "slide_from_left" }} />
              <Stack.Screen name="Create" component={S.Create} options={{ presentation: "fullScreenModal", animation: "slide_from_bottom" }} />
              <Stack.Screen name="Preview" component={S.Preview} options={{ presentation: "fullScreenModal", animation: "fade_from_bottom" }} />
              <Stack.Screen name="Update" component={S.Update} options={{ animation: "slide_from_left" }} />
              <Stack.Screen name="Pair" component={S.Pair} options={{ presentation: "fullScreenModal", animation: "slide_from_bottom" }} />
              <Stack.Screen
                name="InstantPreview"
                component={S.InstantPreview}
                options={{ presentation: "fullScreenModal", animation: "fade_from_bottom" }}
              />
              <Stack.Screen name="Chat" component={S.Chat} options={{ presentation: "fullScreenModal", animation: "slide_from_bottom" }} />
              <Stack.Screen name="Gallery" component={S.Gallery} options={{ presentation: "fullScreenModal", animation: "slide_from_bottom" }} />
            </Stack.Navigator>
          </NavigationContainer>
        </ErrorBoundary>
      </View>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  dockWrap: { position: "absolute", left: 0, right: 0, bottom: 0 },
  dock: {
    flexDirection: "row-reverse",
    alignItems: "flex-end",
    paddingTop: 10,
    paddingHorizontal: space.sm,
    backgroundColor: colors.glassBar,
    borderTopWidth: 1,
    borderColor: colors.glassBorderStrong,
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    shadowColor: colors.glow,
    shadowOpacity: 0.3,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: -6 },
    elevation: 20,
  },
  slot: { flex: 1, alignItems: "center", gap: 4 },
  slotIcon: { width: 44, height: 32, borderRadius: 14, alignItems: "center", justifyContent: "center", overflow: "hidden" },
  slotIconOn: { shadowColor: colors.glow, shadowOpacity: 0.6, shadowRadius: 10, elevation: 8 },
  slotLabel: { fontSize: 11, fontWeight: "700", color: colors.textMuted },
  slotLabelOn: { color: colors.text },
  fab: {
    width: 62,
    height: 62,
    borderRadius: 31,
    marginTop: -34,
    marginBottom: 6,
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
    borderWidth: 4,
    borderColor: colors.base,
    shadowColor: colors.glow,
    shadowOpacity: 0.8,
    shadowRadius: 18,
    elevation: 16,
  },
});
