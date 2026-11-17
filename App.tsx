import React from "react";
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
import { colors, gradient } from "./theme";
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

const TABS: Record<string, { label: string; on: IconName; off: IconName }> = {
  Home: { label: "الرئيسية", on: "home", off: "home-outline" },
  Apps: { label: "تطبيقاتي", on: "apps", off: "apps-outline" },
  Settings: { label: "الإعدادات", on: "settings", off: "settings-outline" },
};

/** Floating pill tab bar, right-to-left: the active tab is a white pill with its label, plus a "new app" button. */
function TabBar({ state, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const items = state.routes.map((route, index) => {
    const focused = state.index === index;
    const t = TABS[route.name];
    return (
      <Pressable
        key={route.key}
        onPress={() => {
          const e = navigation.emit({ type: "tabPress", target: route.key, canPreventDefault: true });
          if (!focused && !e.defaultPrevented) navigation.navigate(route.name);
        }}
        style={[styles.tab, focused && styles.tabOn]}
        accessibilityRole="tab"
        accessibilityState={{ selected: focused }}
        accessibilityLabel={t.label}
      >
        {focused ? (
          <LinearGradient colors={gradient as unknown as string[]} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={[StyleSheet.absoluteFill, { borderRadius: 999 }]} />
        ) : null}
        <Ionicons name={focused ? t.on : t.off} size={20} color={focused ? colors.primaryText : colors.textMuted} />
        {focused ? <Text style={styles.tabLabel}>{t.label}</Text> : null}
      </Pressable>
    );
  });
  const plus = (
    <Pressable
      key="new"
      onPress={() => navigation.getParent()?.navigate("Create")}
      style={({ pressed }) => [styles.plus, pressed && { transform: [{ scale: 0.93 }] }]}
      accessibilityRole="button"
      accessibilityLabel="تطبيق جديد"
    >
      <LinearGradient colors={gradient as unknown as string[]} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={[StyleSheet.absoluteFill, { borderRadius: 999 }]} />
      <Ionicons name="add" size={26} color={colors.primaryText} />
    </Pressable>
  );
  return (
    <View style={[styles.barWrap, { paddingBottom: Math.max(insets.bottom, 12) }]} pointerEvents="box-none">
      <View style={styles.bar}>{[...items, plus]}</View>
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
  barWrap: { position: "absolute", left: 0, right: 0, bottom: 0, alignItems: "center" },
  bar: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: 6,
    padding: 6,
    borderRadius: 999,
    backgroundColor: colors.glassBar,
    borderWidth: 1,
    borderColor: colors.glassBorderStrong,
    shadowColor: colors.glow,
    shadowOpacity: 0.35,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 8 },
    elevation: 16,
  },
  tab: {
    flexDirection: "row-reverse",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    height: 44,
    minWidth: 46,
    paddingHorizontal: 12,
    borderRadius: 999,
    overflow: "hidden",
  },
  tabOn: { paddingHorizontal: 18 },
  tabLabel: { fontSize: 13, fontWeight: "800", color: colors.primaryText },
  plus: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
    marginRight: 2,
    shadowColor: colors.glow,
    shadowOpacity: 0.7,
    shadowRadius: 14,
    elevation: 12,
  },
});
