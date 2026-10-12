import React, { useState } from "react";
import { View, TextInput, Text, TouchableOpacity, StyleSheet, ScrollView, ActivityIndicator } from "react-native";
import * as SecureStore from "expo-secure-store";
import { testGithubConnection } from "../services/github";
import { testSupabaseConnection } from "../services/supabase";
import { testGeminiConnection, testClaudeConnection } from "../services/ai";

function Field({ label, storeKey, secure = true, placeholder }: { label: string; storeKey: string; secure?: boolean; placeholder?: string }) {
  const [value, setValue] = useState("");
  const [saved, setSaved] = useState(false);
  return (
    <View style={{ marginBottom: 16 }}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        style={styles.input}
        value={value}
        onChangeText={(t) => { setValue(t); setSaved(false); }}
        placeholder={placeholder}
        secureTextEntry={secure}
        autoCapitalize="none"
      />
      <TouchableOpacity
        style={styles.saveBtn}
        onPress={async () => {
          if (!value.trim()) return;
          await SecureStore.setItemAsync(storeKey, value.trim());
          setSaved(true);
        }}
      >
        <Text style={{ color: "white" }}>{saved ? "✓ محفوظ" : "حفظ"}</Text>
      </TouchableOpacity>
    </View>
  );
}

export default function ConnectionsScreen() {
  const [githubResult, setGithubResult] = useState<string | null>(null);
  const [supabaseResult, setSupabaseResult] = useState<string | null>(null);
  const [loadingGithub, setLoadingGithub] = useState(false);
  const [loadingSupabase, setLoadingSupabase] = useState(false);
  const [geminiResult, setGeminiResult] = useState<string | null>(null);
  const [claudeResult, setClaudeResult] = useState<string | null>(null);
  const [loadingGemini, setLoadingGemini] = useState(false);
  const [loadingClaude, setLoadingClaude] = useState(false);

  async function handleTestGithub() {
    setLoadingGithub(true);
    setGithubResult(null);
    try {
      const r = await testGithubConnection();
      setGithubResult(`✅ متصل بنجاح باسم: ${r.login}`);
    } catch (e: any) {
      setGithubResult(`❌ ${e.message}`);
    } finally {
      setLoadingGithub(false);
    }
  }

  async function handleTestSupabase() {
    setLoadingSupabase(true);
    setSupabaseResult(null);
    try {
      const r = await testSupabaseConnection();
      setSupabaseResult(`✅ متصل بمشروع: ${r.name} (${r.status})`);
    } catch (e: any) {
      setSupabaseResult(`❌ ${e.message}`);
    } finally {
      setLoadingSupabase(false);
    }
  }

  async function handleTestGemini() {
    setLoadingGemini(true);
    setGeminiResult(null);
    try {
      const r = await testGeminiConnection();
      setGeminiResult(`✅ متصل، عدد النماذج المتاحة: ${r.modelCount}`);
    } catch (e: any) {
      setGeminiResult(`❌ ${e.message}`);
    } finally {
      setLoadingGemini(false);
    }
  }

  async function handleTestClaude() {
    setLoadingClaude(true);
    setClaudeResult(null);
    try {
      await testClaudeConnection();
      setClaudeResult(`✅ متصل بنجاح`);
    } catch (e: any) {
      setClaudeResult(`❌ ${e.message}`);
    } finally {
      setLoadingClaude(false);
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.section}>GitHub</Text>
      <Field label="Personal Access Token" storeKey="GITHUB_TOKEN" placeholder="ghp_..." />
      <Field label="مستودع التطبيق الأول (username/repo)" storeKey="GITHUB_REPO_1" secure={false} placeholder="username/app-one" />
      <Field label="مستودع التطبيق الثاني (username/repo)" storeKey="GITHUB_REPO_2" secure={false} placeholder="username/app-two" />
      <TouchableOpacity style={styles.testBtn} onPress={handleTestGithub}>
        <Text style={{ color: "white" }}>اختبار اتصال GitHub</Text>
      </TouchableOpacity>
      {loadingGithub && <ActivityIndicator style={{ marginTop: 8 }} />}
      {githubResult && <Text style={styles.result}>{githubResult}</Text>}

      <View style={{ height: 24 }} />

      <Text style={styles.section}>Supabase</Text>
      <Text style={styles.hint}>مشروع Supabase ده بيتشارك بين التطبيق الأول والتاني — ده اللي بيربطهم ببعض.</Text>
      <Field label="Personal Access Token (من Account، مش من المشروع)" storeKey="SUPABASE_ACCESS_TOKEN" placeholder="sbp_..." />
      <Field label="Project Ref (من رابط المشروع)" storeKey="SUPABASE_PROJECT_REF" secure={false} placeholder="qlvmxnoewxzykgbneadv" />
      <TouchableOpacity style={styles.testBtn} onPress={handleTestSupabase}>
        <Text style={{ color: "white" }}>اختبار اتصال Supabase</Text>
      </TouchableOpacity>
      {loadingSupabase && <ActivityIndicator style={{ marginTop: 8 }} />}
      {supabaseResult && <Text style={styles.result}>{supabaseResult}</Text>}

      <View style={{ height: 24 }} />

      <Text style={styles.section}>Gemini</Text>
      <Field label="API Key" storeKey="GEMINI_API_KEY" placeholder="AIza..." />
      <TouchableOpacity style={styles.testBtn} onPress={handleTestGemini}>
        <Text style={{ color: "white" }}>اختبار اتصال Gemini</Text>
      </TouchableOpacity>
      {loadingGemini && <ActivityIndicator style={{ marginTop: 8 }} />}
      {geminiResult && <Text style={styles.result}>{geminiResult}</Text>}

      <View style={{ height: 24 }} />

      <Text style={styles.section}>Claude</Text>
      <Field label="API Key" storeKey="CLAUDE_API_KEY" placeholder="sk-ant-..." />
      <TouchableOpacity style={styles.testBtn} onPress={handleTestClaude}>
        <Text style={{ color: "white" }}>اختبار اتصال Claude</Text>
      </TouchableOpacity>
      {loadingClaude && <ActivityIndicator style={{ marginTop: 8 }} />}
      {claudeResult && <Text style={styles.result}>{claudeResult}</Text>}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  section: { fontSize: 18, fontWeight: "700", marginBottom: 12 },
  label: { marginBottom: 6, fontWeight: "600" },
  input: { borderWidth: 1, borderColor: "#ccc", borderRadius: 10, padding: 10, marginBottom: 6 },
  saveBtn: { backgroundColor: "#444", borderRadius: 8, padding: 8, alignItems: "center", alignSelf: "flex-start", paddingHorizontal: 16 },
  testBtn: { backgroundColor: "#111", borderRadius: 10, padding: 12, alignItems: "center", marginTop: 4 },
  result: { marginTop: 10, lineHeight: 20 },
  hint: { color: "#888", fontSize: 12, marginBottom: 10 },
});
