import React from "react";
import { NavigationContainer, DarkTheme } from "@react-navigation/native";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { StatusBar } from "expo-status-bar";
import { View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import CreateScreen from "./screens/CreateScreen";
import PreviewScreen from "./screens/PreviewScreen";
import BuildScreen from "./screens/BuildScreen";
import ConnectionsScreen from "./screens/ConnectionsScreen";
import { colors } from "./theme";

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

const TAB_ICONS: Record<string, [IconName, IconName]> = {
  الإنشاء: ["sparkles", "sparkles-outline"],
  المعاينة: ["eye", "eye-outline"],
  "بناء APK": ["construct", "construct-outline"],
  المفاتيح: ["key", "key-outline"],
};

export default function App() {
  return (
    // Dark root so nothing light shows behind the tab bar's rounded corners.
    <View style={{ flex: 1, backgroundColor: colors.bg }}>
      <NavigationContainer theme={navTheme}>
        <StatusBar style="light" />
        <Tab.Navigator
          screenOptions={({ route }) => ({
            headerShown: true,
            headerStyle: { backgroundColor: colors.bg, borderBottomWidth: 0, elevation: 0, shadowOpacity: 0 },
            headerTitleStyle: { color: colors.text, fontWeight: "800", fontSize: 20 },
            headerShadowVisible: false,
            tabBarStyle: {
              backgroundColor: colors.surface,
              borderTopWidth: 0,
              borderTopLeftRadius: 24,
              borderTopRightRadius: 24,
              height: 72,
              paddingTop: 8,
              paddingBottom: 10,
            },
            tabBarActiveTintColor: colors.accent,
            tabBarInactiveTintColor: colors.textMuted,
            tabBarLabelStyle: { fontSize: 12, fontWeight: "700" },
            tabBarIcon: ({ focused, color }) => {
              const [on, off] = TAB_ICONS[route.name] ?? ["ellipse", "ellipse-outline"];
              return (
                <View
                  style={{
                    paddingHorizontal: 16,
                    paddingVertical: 4,
                    borderRadius: 999,
                    backgroundColor: focused ? colors.primarySoft : "transparent",
                  }}
                >
                  <Ionicons name={focused ? on : off} size={22} color={color} />
                </View>
              );
            },
          })}
        >
          <Tab.Screen name="الإنشاء" component={CreateScreen} />
          <Tab.Screen name="المعاينة" component={PreviewScreen} />
          <Tab.Screen name="بناء APK" component={BuildScreen} />
          <Tab.Screen name="المفاتيح" component={ConnectionsScreen} />
        </Tab.Navigator>
      </NavigationContainer>
    </View>
  );
}
