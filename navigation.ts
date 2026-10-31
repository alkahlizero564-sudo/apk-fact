import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import type { Lang } from "./services/langs";

export type RootStackParamList = {
  Tabs: undefined;
  Create: { templateId?: string } | undefined;
  AppDetail: { name: string; lang: Lang };
  Preview: { name: string };
};

export type RootScreenProps<T extends keyof RootStackParamList> = NativeStackScreenProps<RootStackParamList, T>;
