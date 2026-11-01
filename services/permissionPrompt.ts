import { Alert } from "react-native";
import type { Lang } from "./langs";
import { neededPermissions, approvePermissions, permissionLabels } from "./appActions";

function ask(title: string, text: string): Promise<boolean> {
  return new Promise((resolve) =>
    Alert.alert(
      title,
      text,
      [
        { text: "إلغاء", style: "cancel", onPress: () => resolve(false) },
        { text: "موافق", onPress: () => resolve(true) },
      ],
      { cancelable: true, onDismiss: () => resolve(false) }
    )
  );
}

/**
 * Before a build: when the code uses a permission that was not in the description, tell the owner and add it
 * when they press OK. Returns false when they cancel (the build should not start).
 */
export async function confirmPermissions(apps: { name: string; lang: Lang }[]): Promise<boolean> {
  for (const { name, lang } of apps) {
    let missing: string[] = [];
    try {
      missing = await neededPermissions(name, lang);
    } catch {
      continue; // could not read the code: build anyway, the build log warns about unapproved permissions
    }
    if (!missing.length) continue;
    const ok = await ask(
      "التطبيق محتاج صلاحية",
      `${apps.length > 1 ? `تطبيق ${name} ` : "التطبيق "}محتاج صلاحية: ${permissionLabels(missing)}.\n\n` +
        "الصلاحية دي ما كانت في الوصف، لكن الكود بيستخدمها. نضيفها ونكمّل البناء؟"
    );
    if (!ok) return false;
    await approvePermissions(name, missing);
  }
  return true;
}
