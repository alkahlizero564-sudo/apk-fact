import React from "react";
import { View, Text, Pressable, StyleSheet } from "react-native";
import { NavigationContainer, DarkTheme } from "@react-navigation/native";
import { createBottomTabNavigator, BottomTabBarProps } from "@react-navigation/bottom-tabs";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { SafeAreaProvider, useSafeAreaInsets } from "react-native-safe-area-context";
import { StatusBar } from "expo-status-bar";
import { LinearGradient } from "expo-linear-gradient";
import { Ionicons } from "@expo/vector-icons";

import HomeScreen from "./screens/HomeScreen";
import AppsScreen from "./screens/AppsScreen";
import SettingsScreen from "./screens/SettingsScreen";
import CreateScreen from "./screens/CreateScreen";
import AppDetailScreen from "./screens/AppDetailScreen";
import PreviewScreen from "./screens/PreviewScreen";
import InstantPreviewScreen from "./screens/InstantPreviewScreen";
import PairScreen from "./screens/PairScreen";
import UpdateScreen from "./screens/UpdateScreen";
import { colors, gradient } from "./theme";
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

/** Floating pill tab bar, right-to-left, with the "new app" button in the middle. */
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
        style={styles.tab}
        accessibilityRole="tab"
        accessibilityState={{ selected: focused }}
        accessibilityLabel={t.label}
      >
        <View style={[styles.tabIcon, focused && styles.tabIconOn]}>
          <Ionicons name={focused ? t.on : t.off} size={22} color={focused ? colors.text : colors.textMuted} />
        </View>
        <Text style={[styles.tabLabel, focused && { color: colors.text }]}>{t.label}</Text>
      </Pressable>
    );
  });
  const plus = (
    <Pressable
      key="new"
      onPress={() => navigation.getParent()?.navigate("Create")}
      style={({ pressed }) => [styles.plusWrap, pressed && { transform: [{ scale: 0.94 }] }]}
      accessibilityRole="button"
      accessibilityLabel="تطبيق جديد"
    >
      <LinearGradient colors={gradient} start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} style={styles.plus}>
        <Ionicons name="add" size={30} color={colors.primaryText} />
      </LinearGradient>
    </Pressable>
  );
  return (
    <View style={[styles.barWrap, { paddingBottom: Math.max(insets.bottom, 12) }]} pointerEvents="box-none">
      <View style={styles.bar}>{[items[0], items[1], plus, items[2]]}</View>
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
            </Stack.Navigator>
          </NavigationContainer>
        </ErrorBoundary>
      </View>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  barWrap: { position: "absolute", left: 0, right: 0, bottom: 0, paddingHorizontal: 16 },
  bar: {
    flexDirection: "row-reverse",
    alignItems: "center",
    justifyContent: "space-around",
    height: 72,
    borderRadius: 28,
    backgroundColor: "rgba(16,18,27,0.97)",
    borderWidth: 1,
    borderColor: colors.border,
    paddingHorizontal: 8,
    shadowColor: "#000",
    shadowOpacity: 0.4,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 8 },
    elevation: 16,
  },
  tab: { alignItems: "center", justifyContent: "center", gap: 2, minWidth: 64, height: "100%" },
  tabIcon: { paddingHorizontal: 14, paddingVertical: 4, borderRadius: 999 },
  tabIconOn: { backgroundColor: colors.primarySoft },
  tabLabel: { fontSize: 11, fontWeight: "800", color: colors.textMuted },
  plusWrap: { marginTop: -34 },
  plus: {
    width: 62,
    height: 62,
    borderRadius: 31,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 4,
    borderColor: colors.bg,
  },
});
