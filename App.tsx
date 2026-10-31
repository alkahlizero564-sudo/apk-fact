import React from "react";
import { NavigationContainer, DarkTheme } from "@react-navigation/native";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { StatusBar } from "expo-status-bar";
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
  "الإنشاء": ["sparkles", "sparkles-outline"],
  "المعاينة": ["eye", "eye-outline"],
  "بناء APK": ["construct", "construct-outline"],
  "المفاتيح": ["key", "key-outline"],
};

export default function App() {
  return (
    <NavigationContainer theme={navTheme}>
      <StatusBar style="light" />
      <Tab.Navigator
        screenOptions={({ route }) => ({
          headerShown: true,
          headerStyle: { backgroundColor: colors.bg, borderBottomWidth: 0, elevation: 0, shadowOpacity: 0 },
          headerTitleStyle: { color: colors.text, fontWeight: "800", fontSize: 20 },
          tabBarStyle: {
            backgroundColor: colors.surface,
            borderTopColor: colors.border,
            height: 64,
            paddingTop: 6,
            paddingBottom: 8,
          },
          tabBarActiveTintColor: colors.accent,
          tabBarInactiveTintColor: colors.textMuted,
          tabBarLabelStyle: { fontSize: 12, fontWeight: "700" },
          tabBarIcon: ({ focused, color, size }) => {
            const [on, off] = TAB_ICONS[route.name] ?? ["ellipse", "ellipse-outline"];
            return <Ionicons name={focused ? on : off} size={size} color={color} />;
          },
        })}
      >
        <Tab.Screen name="الإنشاء" component={CreateScreen} />
        <Tab.Screen name="المعاينة" component={PreviewScreen} />
        <Tab.Screen name="بناء APK" component={BuildScreen} />
        <Tab.Screen name="المفاتيح" component={ConnectionsScreen} />
      </Tab.Navigator>
    </NavigationContainer>
  );
}
