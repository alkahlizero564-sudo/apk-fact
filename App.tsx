import React from "react";
import { View, Text, Pressable, StyleSheet } from "react-native";
import { NavigationContainer, DarkTheme } from "@react-navigation/native";
import { createBottomTabNavigator, BottomTabBarProps } from "@react-navigation/bottom-tabs";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { SafeAreaProvider, useSafeAreaInsets } from "react-native-safe-area-context";
import { StatusBar } from "expo-status-bar";
import { Ionicons } from "@expo/vector-icons";

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
import { colors } from "./theme";
import ErrorBoundary from "./components/ErrorBoundary";
import type { RootStackParamList } from "./navigation";

const Stack = createNativeStackNavigator<RootStackParamList>();
const Tab = createBottomTabNavigator();

const navTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    primary: colors.primary,
    background: colors.bg,
    card: colors.surface,
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
        <Ionicons name={focused ? t.on : t.off} size={20} color={focused ? "#000000" : "#8A8A94"} />
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
      <Ionicons name="add" size={24} color="#000000" />
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
      <Tab.Screen name="Home" component={HomeScreen} />
      <Tab.Screen name="Apps" component={AppsScreen} />
      <Tab.Screen name="Settings" component={SettingsScreen} />
    </Tab.Navigator>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <View style={{ flex: 1, backgroundColor: colors.bg }}>
        <ErrorBoundary>
          <NavigationContainer theme={navTheme}>
            <StatusBar style="light" />
            <Stack.Navigator screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.bg } }}>
              <Stack.Screen name="Tabs" component={Tabs} />
              <Stack.Screen name="AppDetail" component={AppDetailScreen} options={{ animation: "slide_from_left" }} />
              <Stack.Screen name="Create" component={CreateScreen} options={{ presentation: "fullScreenModal", animation: "slide_from_bottom" }} />
              <Stack.Screen name="Preview" component={PreviewScreen} options={{ presentation: "fullScreenModal", animation: "fade_from_bottom" }} />
              <Stack.Screen name="Update" component={UpdateScreen} options={{ animation: "slide_from_left" }} />
              <Stack.Screen name="Pair" component={PairScreen} options={{ presentation: "fullScreenModal", animation: "slide_from_bottom" }} />
              <Stack.Screen
                name="InstantPreview"
                component={InstantPreviewScreen}
                options={{ presentation: "fullScreenModal", animation: "fade_from_bottom" }}
              />
              <Stack.Screen name="Chat" component={ChatScreen} options={{ presentation: "fullScreenModal", animation: "slide_from_bottom" }} />
              <Stack.Screen name="Gallery" component={GalleryScreen} options={{ presentation: "fullScreenModal", animation: "slide_from_bottom" }} />
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
    backgroundColor: "#16161A",
    borderWidth: 1,
    borderColor: "#23232A",
    shadowColor: "#000",
    shadowOpacity: 0.5,
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
  },
  tabOn: { backgroundColor: "#FFFFFF", paddingHorizontal: 18 },
  tabLabel: { fontSize: 13, fontWeight: "700", color: "#000000" },
  plus: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#FFFFFF",
    marginRight: 2,
  },
});
