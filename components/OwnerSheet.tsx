// The first question when creating an app or a connected pair: is it the owner's own, or for a client?
// For a pair, a client means the client's own database project (services/projects.ts); for one app it is the
// client's name, kept with the app (apps/<app>/client.txt).
import React, { useEffect, useState } from "react";
import { View, Text, StyleSheet, Pressable } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { Sheet, Button, Chip, Field } from "./ui";
import DbProjectsPanel from "./DbProjectsPanel";
import { listProjects, DbProject } from "../services/projects";
import { cleanLabel } from "../services/appActions";
import { colors, radius, space, type } from "../theme";

export type Owner = { kind: "mine" } | { kind: "client"; name: string; ref?: string };

type Props = { visible: boolean; pair?: boolean; onPick: (o: Owner) => void; onClose: () => void };

export default function OwnerSheet({ visible, pair, onPick, onClose }: Props) {
  const [forClient, setForClient] = useState(false);
  const [projects, setProjects] = useState<DbProject[]>([]);
  const [name, setName] = useState("");
  const [adding, setAdding] = useState(false);

  useEffect(() => {
    if (visible) listProjects().then(setProjects);
  }, [visible]);

  const Big = ({ icon, title, sub, onPress }: { icon: any; title: string; sub: string; onPress: () => void }) => (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.big, pressed && { opacity: 0.85 }]} accessibilityRole="button">
      <Ionicons name={icon} size={30} color={colors.primary} />
      <View style={{ flex: 1 }}>
        <Text style={styles.bigTitle}>{title}</Text>
        <Text style={styles.bigSub}>{sub}</Text>
      </View>
      <Ionicons name="chevron-back" size={20} color={colors.textMuted} />
    </Pressable>
  );

  return (
    <Sheet visible={visible} title={pair ? "التطبيقين دول لمين؟" : "التطبيق ده لمين؟"} onClose={onClose}>
      {!forClient ? (
        <View style={{ gap: space.md }}>
          <Big
            icon="home-outline"
            title="لي (الأساسي)"
            sub={pair ? "في مشروع Supabase الأساسي بتاعك" : "تطبيق خاص بيك"}
            onPress={() => onPick({ kind: "mine" })}
          />
          <Big
            icon="person-outline"
            title="لزبون"
            sub={pair ? "في قاعدة بيانات خاصة بالزبون، منفصلة عن باقي الزباين" : "يتسجّل باسم الزبون"}
            onPress={() => setForClient(true)}
          />
        </View>
      ) : adding ? (
        <DbProjectsPanel
          showList={false}
          onAdded={(p) => {
            setAdding(false);
            onPick({ kind: "client", name: p.label, ref: p.ref });
          }}
        />
      ) : (
        <View>
          <Text style={styles.label}>{pair ? "اختار قاعدة بيانات الزبون" : "اختار الزبون أو اكتب اسمه"}</Text>
          {projects.length ? (
            <View style={styles.chips}>
              {projects.map((p) => (
                <Chip
                  key={p.ref}
                  label={p.label}
                  icon="server-outline"
                  onPress={() => onPick({ kind: "client", name: p.label, ref: p.ref })}
                />
              ))}
            </View>
          ) : (
            <Text style={styles.hint}>{pair ? "لسه ما في قواعد بيانات زباين." : "لسه ما في زباين محفوظين."}</Text>
          )}
          {pair ? (
            <Button title="أضف قاعدة بيانات لزبون جديد" icon="add-circle-outline" onPress={() => setAdding(true)} />
          ) : (
            <>
              <Field label="اسم زبون جديد" icon="person-outline" value={name} onChangeText={setName} placeholder="مثال: محل الورد" maxLength={40} />
              <Button
                title="تمام"
                icon="checkmark"
                disabled={!cleanLabel(name)}
                onPress={() => onPick({ kind: "client", name: cleanLabel(name) })}
              />
            </>
          )}
          <Button title="رجوع" variant="secondary" onPress={() => setForClient(false)} style={{ marginTop: space.md }} />
        </View>
      )}
    </Sheet>
  );
}

const styles = StyleSheet.create({
  big: {
    flexDirection: "row-reverse",
    alignItems: "center",
    gap: space.md,
    padding: space.lg,
    borderRadius: radius.card,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.surfaceAlt,
  },
  bigTitle: { ...type.sectionTitle, color: colors.text, textAlign: "right" },
  bigSub: { ...type.hint, color: colors.textMuted, textAlign: "right", marginTop: 2 },
  label: { ...type.label, color: colors.text, textAlign: "right", marginBottom: space.sm },
  hint: { ...type.hint, color: colors.textMuted, textAlign: "right", marginBottom: space.md },
  chips: { flexDirection: "row-reverse", flexWrap: "wrap", gap: space.sm, marginBottom: space.md },
});
