import React from "react";
import { NavigationContainer } from "@react-navigation/native";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { StatusBar } from "expo-status-bar";

import CreateScreen from "./screens/CreateScreen";
import PreviewScreen from "./screens/PreviewScreen";
import BuildScreen from "./screens/BuildScreen";
import ConnectionsScreen from "./screens/ConnectionsScreen";

const Tab = createBottomTabNavigator();

export default function App() {
  return (
    <NavigationContainer>
      <StatusBar style="auto" />
      <Tab.Navigator screenOptions={{ headerShown: true }}>
        <Tab.Screen name="الإنشاء" component={CreateScreen} />
        <Tab.Screen name="المعاينة" component={PreviewScreen} />
        <Tab.Screen name="بناء APK" component={BuildScreen} />
        <Tab.Screen name="المفاتيح" component={ConnectionsScreen} />
      </Tab.Navigator>
    </NavigationContainer>
  );
}
