// The design gallery: thousands of starting designs made from every combination of an app CATEGORY, a visual
// STYLE (design school) and a color PALETTE. Picking one becomes the start of the owner's app — the AI builds a
// complete app on that category and is told to follow that exact style and palette. Previews are drawn from the
// palette/style (no AI, instant, offline); the full brief is built only when one is picked.
import { Ionicons } from "@expo/vector-icons";
import { Lang } from "./langs";
import { Template } from "./templates";

type IconName = React.ComponentProps<typeof Ionicons>["name"];

export type Category = { key: string; title: string; icon: IconName; name: string; lang: Lang; desc: string };
export type DesignStyle = { key: string; title: string; directive: string; radius: number; border: boolean; soft: boolean };
export type Palette = { key: string; name: string; primary: string; accent: string; bg: string; surface: string; text: string; muted: string };

export const CATEGORIES: Category[] = [
  { key: "store", title: "متجر إلكتروني", icon: "bag-handle-outline", name: "store", lang: "html",
    desc: "متجر إلكتروني لبيع المنتجات. الشاشات: الرئيسية فيها بانر عروض وتصنيفات ومنتجات مميّزة، صفحة المنتج بالصور والمقاسات والألوان والسعر، سلة بتعديل الكمية والإجمالي، المفضلة، وإتمام الطلب بالاسم والعنوان والهاتف. بحث وفلترة." },
  { key: "restaurant", title: "منيو مطعم", icon: "restaurant-outline", name: "restaurant", lang: "html",
    desc: "تطبيق منيو لمطعم. أقسام: مقبلات، أطباق رئيسية، مشروبات، حلويات، لكل صنف صورة واسم ووصف وسعر وزر إضافة. سلة بالكميات والإجمالي، اختيار استلام أو توصيل، وإرسال الطلب." },
  { key: "delivery", title: "طلبات وتوصيل", icon: "bicycle-outline", name: "delivery", lang: "html",
    desc: "تطبيق توصيل. الرئيسية فيها بحث وعروض وتصنيفات وأصناف بالصور والأسعار، صفحة الصنف بالإضافات والكمية، السلة بالإجمالي ورسوم التوصيل، إتمام الطلب بالعنوان والهاتف وطريقة الدفع، وتتبّع الطلب بخط زمني، وطلباتي السابقة." },
  { key: "cafe", title: "كافيه ومشروبات", icon: "cafe-outline", name: "cafe", lang: "html",
    desc: "تطبيق كافيه. منيو المشروبات الساخنة والباردة والحلويات بالصور والأسعار، تخصيص المشروب (الحجم، السكر، الإضافات)، سلة وطلب، ونقاط ولاء للعملاء." },
  { key: "grocery", title: "بقالة وسوبرماركت", icon: "basket-outline", name: "grocery", lang: "html",
    desc: "تطبيق بقالة. تصنيفات (خضار، فواكه، ألبان، معلّبات، منظّفات)، منتجات بالصور والأسعار والوحدة، سلة ذكية، قوائم مشتريات محفوظة، وإتمام الطلب بالعنوان." },
  { key: "booking", title: "حجز مواعيد", icon: "calendar-outline", name: "booking", lang: "html",
    desc: "تطبيق حجز مواعيد. اختيار الخدمة والسعر والمدة، تقويم لاختيار اليوم والوقت من المتاح، إدخال الاسم والهاتف، تأكيد الحجز، وقائمة حجوزاتي مع الإلغاء." },
  { key: "clinic", title: "عيادة وصحة", icon: "medkit-outline", name: "clinic", lang: "html",
    desc: "تطبيق عيادة. حجز موعد مع طبيب حسب التخصّص، ملف المريض وتاريخه، التذكير بالأدوية بأوقاتها، نتائج الفحوصات، وتواصل مع العيادة." },
  { key: "pharmacy", title: "صيدلية", icon: "bandage-outline", name: "pharmacy", lang: "html",
    desc: "تطبيق صيدلية. بحث عن دواء أو منتج، تصنيفات (أدوية، عناية، أطفال، فيتامينات)، صفحة المنتج بالوصف والسعر، سلة وطلب بوصفة أو بدونها، وتوصيل." },
  { key: "gym", title: "نادٍ رياضي", icon: "barbell-outline", name: "gym", lang: "flutter",
    desc: "تطبيق نادٍ رياضي. خطط تمارين حسب المستوى، صفحة التمرين بالخطوات والعدّات والمجموعات ومؤقّت راحة، جدول حصص، اشتراكات، وإحصائيات تقدّم أسبوعية." },
  { key: "fitness", title: "لياقة وتمارين", icon: "fitness-outline", name: "fitness", lang: "flutter",
    desc: "تطبيق لياقة. تمارين منزلية بالخطوات والصور، مؤقّتات، تتبّع السعرات والماء، أيام متتالية، وشاشة إحصائيات أسبوعية." },
  { key: "tasks", title: "مهام ومشاريع", icon: "checkbox-outline", name: "tasks", lang: "flutter",
    desc: "تطبيق مهام. إضافة مهمة بعنوان وملاحظة وتاريخ استحقاق وأولوية وتصنيف، تبويبات (اليوم، القادمة، المنجزة)، تعليم كمنجز، عدّاد وشريط تقدّم يومي." },
  { key: "notes", title: "ملاحظات", icon: "document-text-outline", name: "notes", lang: "flutter",
    desc: "تطبيق ملاحظات. بطاقات ملوّنة في شبكة، إضافة وتعديل بعنوان ونص ولون، تثبيت المهم، بحث فوري، وحذف مع تراجع." },
  { key: "wallet", title: "محفظة ومصاريف", icon: "wallet-outline", name: "wallet", lang: "html",
    desc: "محفظة شخصية. الرصيد الحالي وبطاقات الدخل والمصروف ورسم أسبوعي، إضافة عملية بالمبلغ والتصنيف والتاريخ، فلترة، وميزانية شهرية مع تنبيه عند التجاوز." },
  { key: "budget", title: "ميزانية وادّخار", icon: "pie-chart-outline", name: "budget", lang: "html",
    desc: "تطبيق ميزانية وادّخار. أهداف ادّخار بمبلغ وموعد وشريط تقدّم، توزيع الدخل على التصنيفات، تقارير شهرية بالنِّسب، وتنبيهات الإنفاق." },
  { key: "portfolio", title: "ملف أعمال", icon: "person-circle-outline", name: "portfolio", lang: "html",
    desc: "ملف أعمال (بورتفوليو). صورة واسم ونبذة، المهارات بأشرطة، معرض الأعمال بالصور مع فلترة، الخبرات بخط زمني، وأزرار تواصل." },
  { key: "landing", title: "صفحة تعريفية", icon: "sparkles-outline", name: "landing", lang: "html",
    desc: "صفحة تعريفية لمنتج أو خدمة. قسم بطل بعنوان جذّاب وزر، المزايا بأيقونات، آراء العملاء، الأسعار، أسئلة شائعة، وتواصل." },
  { key: "blog", title: "مدوّنة وأخبار", icon: "newspaper-outline", name: "blog", lang: "html",
    desc: "تطبيق مدوّنة/أخبار. قائمة مقالات بصورة وعنوان ومقتطف وتاريخ، تصنيفات، صفحة المقال بمحتوى منسّق، مقالات مقترحة، وحفظ للقراءة لاحقاً." },
  { key: "recipes", title: "وصفات طبخ", icon: "fast-food-outline", name: "recipes", lang: "html",
    desc: "تطبيق وصفات. تصنيفات المطابخ، بطاقة الوصفة بالصورة والوقت والمكوّنات وخطوات التحضير، المفضلة، وقائمة تسوّق للمكوّنات." },
  { key: "travel", title: "سفر وسياحة", icon: "airplane-outline", name: "travel", lang: "html",
    desc: "تطبيق سفر. وجهات بالصور والوصف، باقات بالأسعار، حجز رحلة أو فندق، خط سير اليوم، والمفضلة." },
  { key: "hotel", title: "فندق وإقامة", icon: "bed-outline", name: "hotel", lang: "html",
    desc: "تطبيق فندق. أنواع الغرف بالصور والمزايا والسعر لليلة، اختيار تواريخ الوصول والمغادرة وعدد الضيوف، حجز، وخدمات الفندق." },
  { key: "events", title: "فعاليات وتذاكر", icon: "ticket-outline", name: "events", lang: "html",
    desc: "تطبيق فعاليات. قائمة فعاليات بالصورة والتاريخ والمكان والسعر، صفحة الفعالية بالتفاصيل والخريطة، حجز تذاكر بعددها، وتذاكري." },
  { key: "realestate", title: "عقارات", icon: "home-outline", name: "realestate", lang: "html",
    desc: "تطبيق عقارات. عروض بالصور والسعر والمساحة والموقع، فلترة (نوع، غرف، سعر)، صفحة العقار بالتفاصيل والصور والمزايا، المفضلة، وتواصل مع المعلن." },
  { key: "cars", title: "سيارات ومعرض", icon: "car-sport-outline", name: "cars", lang: "html",
    desc: "تطبيق معرض سيارات. سيارات بالصور والسعر والموديل والسنة، فلترة، صفحة السيارة بالمواصفات والصور، حجز قيادة تجريبية، والمقارنة." },
  { key: "jobs", title: "وظائف وتوظيف", icon: "briefcase-outline", name: "jobs", lang: "html",
    desc: "تطبيق وظائف. قائمة وظائف بالمسمّى والشركة والموقع والراتب، فلترة وبحث، صفحة الوظيفة بالوصف والمتطلبات، تقديم بالسيرة، ووظائفي المحفوظة." },
  { key: "education", title: "تعليم ودورات", icon: "school-outline", name: "courses", lang: "html",
    desc: "تطبيق دورات تعليمية. تصنيفات، بطاقة الدورة بالصورة والمدرّب والمدّة والسعر، محتوى الدورة بالدروس ونسبة التقدّم، والمفضلة." },
  { key: "quiz", title: "مسابقة أسئلة", icon: "help-circle-outline", name: "quiz", lang: "python",
    desc: "تطبيق مسابقة أسئلة. اختيار التصنيف، أسئلة اختيار من متعدّد مع مؤقّت، إظهار الصحيح بعد الاختيار، شاشة نتيجة بالنقاط، وحفظ أعلى نتيجة." },
  { key: "kids", title: "أطفال وتعليم", icon: "balloon-outline", name: "kids", lang: "html",
    desc: "تطبيق أطفال تعليمي. أنشطة ممتعة (حروف، أرقام، ألوان، أشكال) ببطاقات كبيرة ملوّنة وأصوات، مكافآت ونجوم، وتصميم بسيط وآمن للأطفال." },
  { key: "social", title: "مجتمع وتواصل", icon: "people-outline", name: "social", lang: "flutter",
    desc: "واجهة تطبيق تواصل. خلاصة منشورات بالصورة والاسم والنص والإعجابات والتعليقات، نشر جديد، الملف الشخصي، والإشعارات. بيانات تجريبية واقعية." },
  { key: "chat", title: "دردشة ومحادثات", icon: "chatbubbles-outline", name: "chat", lang: "flutter",
    desc: "واجهة دردشة. قائمة محادثات بالصورة والاسم وآخر رسالة والوقت وعدّاد غير المقروء، شاشة محادثة بفقاعات ووقت وحالة قراءة، وحقل إرسال." },
  { key: "music", title: "مشغّل موسيقى", icon: "musical-notes-outline", name: "music", lang: "flutter",
    desc: "واجهة مشغّل موسيقى. قوائم تشغيل وألبومات بالأغلفة، شاشة التشغيل بالغلاف وشريط التقدّم وأزرار التحكّم، المفضّلة، والبحث." },
  { key: "photography", title: "تصوير ومعرض", icon: "camera-outline", name: "photos", lang: "html",
    desc: "تطبيق معرض صور لمصوّر. شبكة أعمال بفلترة حسب النوع، عرض الصورة بملء الشاشة بالتفاصيل، ألبومات، وتواصل للحجز." },
  { key: "barber", title: "حلاقة وتجميل", icon: "cut-outline", name: "barber", lang: "html",
    desc: "تطبيق صالون حلاقة/تجميل. الخدمات بالأسعار والمدّة، حجز موعد من تقويم ومواعيد متاحة، معرض أعمال، وحجوزاتي." },
  { key: "laundry", title: "مغسلة ملابس", icon: "shirt-outline", name: "laundry", lang: "html",
    desc: "تطبيق مغسلة. أنواع الخدمات (غسيل، كي، تنظيف جاف) بالأسعار للقطعة، سلة الطلب، جدولة الاستلام والتسليم بالعنوان، وتتبّع الطلب." },
  { key: "charity", title: "خير وتبرّعات", icon: "heart-outline", name: "charity", lang: "html",
    desc: "تطبيق تبرّعات. حملات بالصورة والهدف وشريط التقدّم، صفحة الحملة بالتفاصيل، تبرّع بمبلغ، وتبرّعاتي السابقة." },
  { key: "news", title: "رياضة ونتائج", icon: "football-outline", name: "sports", lang: "html",
    desc: "تطبيق رياضي. مباريات اليوم بالفرق والوقت والنتيجة، ترتيب الدوري بجدول، أخبار، وتنبيهات المفضّلة. بيانات تجريبية واقعية." },
  { key: "weather", title: "طقس", icon: "partly-sunny-outline", name: "weather", lang: "html",
    desc: "تطبيق طقس. حالة اليوم بالحرارة والأيقونة والتفاصيل (رطوبة، رياح)، توقّعات الساعات والأيام، إضافة مدن، وخلفية تتغيّر حسب الطقس. بيانات تجريبية." },
  { key: "habits", title: "عادات يومية", icon: "repeat-outline", name: "habits", lang: "flutter",
    desc: "تطبيق عادات. إضافة عادة باسم وأيقونة ولون وأيام تكرار، عادات اليوم بعلامة إنجاز، سلسلة أيام متتالية، وتقويم شهري للالتزام." },
];

export const STYLES: DesignStyle[] = [
  { key: "minimal", title: "مينيمال نظيف", radius: 16, border: true, soft: false,
    directive: "تصميم مينيمال نظيف: مساحات بيضاء واسعة، حدود رفيعة، خطوط واضحة، ألوان قليلة ومنضبطة، وبساطة أنيقة." },
  { key: "soft", title: "ناعم ودائري", radius: 26, border: false, soft: true,
    directive: "تصميم ناعم: زوايا دائرية كبيرة، ظلال خفيفة، بطاقات منفوخة قليلاً، وإحساس ودود مريح." },
  { key: "glass", title: "زجاجي شفّاف", radius: 22, border: true, soft: true,
    directive: "تصميم زجاجي (glassmorphism): طبقات شبه شفّافة مع ضبابية خلفية، حدود مضيئة رقيقة، وتدرّجات ناعمة خلف العناصر." },
  { key: "neo", title: "نيو-بروتال جريء", radius: 8, border: true, soft: false,
    directive: "تصميم نيو-بروتال: حدود سميكة سوداء، ظلال صلبة مُزاحة، ألوان جريئة متباينة، وخطوط عريضة قوية." },
  { key: "editorial", title: "تحريري أنيق", radius: 6, border: false, soft: false,
    directive: "تصميم تحريري راقٍ كالمجلات: تباين كبير في أحجام الخطوط، عناوين كبيرة بخط حادّ، شبكة منظّمة، وصور بارزة." },
  { key: "luxe", title: "فاخر راقٍ", radius: 14, border: true, soft: false,
    directive: "تصميم فاخر: خلفية داكنة أنيقة، لمسات ذهبية/معدنية، تباعد مريح، وخطوط رفيعة راقية تعطي إحساساً بالرُّقي." },
  { key: "gradient", title: "تدرّجات حيوية", radius: 22, border: false, soft: true,
    directive: "تصميم بتدرّجات لونية حيوية: خلفيات وأزرار بتدرّجات زاهية، إضاءة ملوّنة، وإحساس عصري نابض بالحياة." },
  { key: "material", title: "ماتيريال", radius: 18, border: false, soft: true,
    directive: "تصميم Material You: بطاقات مرتفعة بظلال واضحة، ألوان ممتلئة، أزرار دائرية، وحركات انتقال سلسة." },
  { key: "neon", title: "نيون داكن", radius: 16, border: true, soft: false,
    directive: "تصميم داكن بلمسات نيون: خلفية سوداء/كحلية عميقة، ألوان نيون متوهّجة للعناصر المهمة، وحدود مضيئة." },
  { key: "pastel", title: "باستيل هادئ", radius: 24, border: false, soft: true,
    directive: "تصميم باستيل هادئ: ألوان فاتحة لطيفة، تباين منخفض مريح للعين، زوايا دائرية، وإحساس بسيط مطمئن." },
];

export const PALETTES: Palette[] = [
  { key: "indigo", name: "بنفسجي ملكي", primary: "#6E4BFF", accent: "#22D3EE", bg: "#0e0f15", surface: "#171923", text: "#f2f3f8", muted: "#9a9cb0" },
  { key: "emerald", name: "أخضر زمرّدي", primary: "#10B981", accent: "#F59E0B", bg: "#0c1411", surface: "#132019", text: "#eafff5", muted: "#8fb3a4" },
  { key: "rose", name: "وردي دافئ", primary: "#F43F5E", accent: "#FB923C", bg: "#140d10", surface: "#201319", text: "#fff0f3", muted: "#b78f98" },
  { key: "ocean", name: "أزرق محيطي", primary: "#2563EB", accent: "#06B6D4", bg: "#0a1020", surface: "#111a2e", text: "#eef4ff", muted: "#8ea0bf" },
  { key: "sunset", name: "غروب برتقالي", primary: "#F97316", accent: "#EF4444", bg: "#17100a", surface: "#231811", text: "#fff4ea", muted: "#bfa088" },
  { key: "amber", name: "عسلي ذهبي", primary: "#D4A017", accent: "#92400E", bg: "#15110a", surface: "#201a0f", text: "#fff8e8", muted: "#bba875" },
  { key: "teal", name: "فيروزي", primary: "#14B8A6", accent: "#6366F1", bg: "#0a1413", surface: "#10201e", text: "#e8fffb", muted: "#86b2ab" },
  { key: "grape", name: "عنبي", primary: "#A855F7", accent: "#EC4899", bg: "#120d18", surface: "#1d1428", text: "#f8efff", muted: "#a994bb" },
  { key: "slate", name: "رمادي راقٍ", primary: "#64748B", accent: "#0EA5E9", bg: "#0e1013", surface: "#181b20", text: "#eef1f5", muted: "#9aa3af" },
  { key: "cherry", name: "كرزي", primary: "#DC2626", accent: "#F59E0B", bg: "#140b0b", surface: "#201111", text: "#fff0ef", muted: "#bb9090" },
  { key: "lime", name: "ليموني حيوي", primary: "#65A30D", accent: "#0891B2", bg: "#101407", surface: "#19200c", text: "#f4ffe4", muted: "#a0b383" },
  { key: "mint", name: "نعناعي فاتح", primary: "#059669", accent: "#7C3AED", bg: "#0b1512", surface: "#11211c", text: "#e9fff7", muted: "#89b2a4" },
];


// Connected pairs (customer app + admin app on one backend). Same styles and palettes; picking one opens the pair
// screen with the business described for BOTH apps and the visual identity to follow.
export const PAIR_CATEGORIES: Category[] = [
  { key: "p-restaurant", title: "مطعم وطلبات", icon: "restaurant-outline", name: "restaurant", lang: "flutter",
    desc: "مطعم: الزبون يتصفح المنيو بالأقسام والصور والأسعار ويطلب (استلام أو توصيل) ويتابع حالة طلبه، والإدارة تستقبل الطلبات وتغيّر حالتها (جديد، قيد التحضير، في الطريق، تم التسليم) وتدير المنيو والأسعار والعروض." },
  { key: "p-store", title: "متجر وتوصيل", icon: "bag-handle-outline", name: "store", lang: "flutter",
    desc: "متجر: الزبون يتصفح المنتجات حسب التصنيف ويبحث ويضيف للسلة ويطلب مع عنوان التوصيل ويتابع الطلب، والإدارة تدير المنتجات والتصنيفات والمخزون وتستقبل الطلبات وتحدّث حالة التوصيل." },
  { key: "p-grocery", title: "بقالة وسوبرماركت", icon: "basket-outline", name: "grocery", lang: "flutter",
    desc: "بقالة: الزبون يتصفح الأقسام (خضار، فواكه، ألبان، معلّبات) ويطلب بالتوصيل ويتابع طلبه، والإدارة تدير الأصناف والأسعار والمخزون وتجهّز الطلبات وتحدّث حالتها." },
  { key: "p-cafe", title: "كافيه وطلبات", icon: "cafe-outline", name: "cafe", lang: "flutter",
    desc: "كافيه: الزبون يتصفح المشروبات والحلويات ويخصّص طلبه (الحجم، السكر، الإضافات) ويطلب ويجمع نقاط ولاء، والإدارة تستقبل الطلبات وتحدّث حالتها وتدير المنيو والنقاط." },
  { key: "p-salon", title: "صالون وحجوزات", icon: "cut-outline", name: "salon", lang: "flutter",
    desc: "صالون: الزبون يختار الخدمة واليوم والوقت المتاح ويحجز ويلغي حجزه، والإدارة تدير الخدمات والأسعار والمواعيد المتاحة وتؤكد أو ترفض الحجوزات." },
  { key: "p-clinic", title: "عيادة ومواعيد", icon: "medkit-outline", name: "clinic", lang: "flutter",
    desc: "عيادة: المريض يحجز موعداً مع الطبيب حسب التخصّص ويشوف مواعيده ونتائج الزيارات، والإدارة تدير الأطباء والمواعيد وتؤكد الحجوزات وتسجّل ملاحظات الزيارة." },
  { key: "p-pharmacy", title: "صيدلية وطلبات", icon: "bandage-outline", name: "pharmacy", lang: "flutter",
    desc: "صيدلية: الزبون يبحث عن الدواء ويطلبه (مع صورة الوصفة إن لزم) ويتابع التوصيل، والإدارة تدير الأصناف والمخزون وتراجع الطلبات والوصفات وتحدّث حالتها." },
  { key: "p-gym", title: "نادٍ واشتراكات", icon: "barbell-outline", name: "gym", lang: "flutter",
    desc: "نادٍ رياضي: العضو يشوف اشتراكه وجدول الحصص ويحجز حصة ويتابع تمارينه، والإدارة تدير الأعضاء والاشتراكات والحصص والمدرّبين وتؤكد الحجوزات." },
  { key: "p-laundry", title: "مغسلة واستلام", icon: "shirt-outline", name: "laundry", lang: "flutter",
    desc: "مغسلة: الزبون يختار الخدمات (غسيل، كي، تنظيف جاف) ويحدّد موعد الاستلام والتسليم بالعنوان ويتابع الطلب، والإدارة تستقبل الطلبات وتحدّث حالتها وتدير الأسعار." },
  { key: "p-delivery", title: "توصيل ومندوبين", icon: "bicycle-outline", name: "delivery", lang: "flutter",
    desc: "شركة توصيل: الزبون ينشئ طلب توصيل (من، إلى، وصف الشحنة) ويتابع حالته بخط زمني، والإدارة تستقبل الطلبات وتعيّنها وتحدّث حالاتها (تم الاستلام، في الطريق، تم التسليم)." },
  { key: "p-school", title: "مدرسة وأولياء أمور", icon: "school-outline", name: "school", lang: "flutter",
    desc: "مدرسة: وليّ الأمر يشوف حضور ودرجات ابنه والواجبات والإعلانات، والإدارة تسجّل الحضور والدرجات وتنشر الواجبات والإعلانات وتدير الطلاب والفصول." },
  { key: "p-courses", title: "دورات وطلاب", icon: "book-outline", name: "courses", lang: "flutter",
    desc: "مركز دورات: الطالب يتصفح الدورات ويسجّل فيها ويتابع دروسه وتقدّمه، والإدارة تدير الدورات والدروس والتسجيلات وتتابع الطلاب." },
  { key: "p-realestate", title: "عقارات وطلبات معاينة", icon: "home-outline", name: "realestate", lang: "flutter",
    desc: "مكتب عقارات: الزبون يتصفح العقارات بالصور والسعر والموقع ويطلب معاينة أو يستفسر، والإدارة تدير العقارات وتستقبل طلبات المعاينة والاستفسارات وتردّ عليها." },
  { key: "p-cars", title: "تأجير سيارات", icon: "car-sport-outline", name: "carrental", lang: "flutter",
    desc: "تأجير سيارات: الزبون يتصفح السيارات ويحجز بتواريخ الاستلام والإرجاع ويتابع حجزه، والإدارة تدير السيارات والأسعار والتوفّر وتؤكد أو ترفض الحجوزات." },
  { key: "p-hotel", title: "فندق وحجوزات", icon: "bed-outline", name: "hotel", lang: "flutter",
    desc: "فندق: الضيف يتصفح الغرف ويحجز بتواريخ الوصول والمغادرة ويطلب خدمات الغرف، والإدارة تدير الغرف والأسعار والحجوزات وتستقبل طلبات الخدمة." },
  { key: "p-events", title: "فعاليات وتذاكر", icon: "ticket-outline", name: "events", lang: "flutter",
    desc: "فعاليات: الزبون يتصفح الفعاليات ويحجز تذاكر ويشوف تذاكره، والإدارة تنشئ الفعاليات وتدير المقاعد والأسعار وتتابع الحجوزات." },
  { key: "p-maintenance", title: "صيانة وطلبات خدمة", icon: "construct-outline", name: "maintenance", lang: "flutter",
    desc: "شركة صيانة: الزبون يطلب خدمة (سباكة، كهرباء، تكييف) بوصف المشكلة والعنوان والموعد ويتابع الطلب، والإدارة تستقبل الطلبات وتعيّن الفنّي وتحدّث الحالة والتكلفة." },
  { key: "p-bakery", title: "مخبز وطلبات", icon: "pizza-outline", name: "bakery", lang: "flutter",
    desc: "مخبز وحلويات: الزبون يتصفح الأصناف ويطلب (أو يحجز طلباً خاصاً بموعد) ويتابع طلبه، والإدارة تدير الأصناف والأسعار وتستقبل الطلبات وتحدّث حالتها." },
  { key: "p-charity", title: "جمعية وتبرّعات", icon: "heart-outline", name: "charity", lang: "flutter",
    desc: "جمعية خيرية: المتبرّع يتصفح الحملات ويسجّل تبرّعه ويشوف تبرّعاته، والإدارة تنشئ الحملات وتتابع التبرّعات وتنشر التحديثات." },
  { key: "p-support", title: "شكاوى وخدمة عملاء", icon: "chatbubbles-outline", name: "support", lang: "flutter",
    desc: "خدمة عملاء: الزبون يفتح تذكرة (شكوى أو استفسار) ويتابع الردود، والإدارة تستقبل التذاكر وتردّ عليها وتغيّر حالتها (جديدة، قيد المعالجة، مغلقة)." },
];

export const PAIR_GALLERY_COUNT = PAIR_CATEGORIES.length * STYLES.length * PALETTES.length;

export type GalleryItem = { id: string; title: string; icon: IconName; lang: Lang; cat: Category; style: DesignStyle; palette: Palette; pair?: boolean };

export const GALLERY_COUNT = CATEGORIES.length * STYLES.length * PALETTES.length;

function makeItem(cat: Category, style: DesignStyle, palette: Palette): GalleryItem {
  return { id: `g-${cat.key}-${style.key}-${palette.key}`, title: `${cat.title} · ${style.title}`, icon: cat.icon, lang: cat.lang, cat, style, palette };
}

/** All gallery items (optionally filtered by a category key and/or a search query). Items are lightweight. */
export function buildGallery(opts?: { category?: string; query?: string; pair?: boolean }): GalleryItem[] {
  const q = (opts?.query ?? "").trim().toLowerCase();
  const out: GalleryItem[] = [];
  for (const cat of opts?.pair ? PAIR_CATEGORIES : CATEGORIES) {
    if (opts?.category && opts.category !== "all" && cat.key !== opts.category) continue;
    for (const style of STYLES) {
      for (const palette of PALETTES) {
        if (q) {
          const hay = `${cat.title} ${style.title} ${palette.name}`.toLowerCase();
          if (!hay.includes(q)) continue;
        }
        out.push(opts?.pair ? { ...makeItem(cat, style, palette), pair: true } : makeItem(cat, style, palette));
      }
    }
  }
  return out;
}

/** Turn a picked gallery item into a full Template (used as the start of the owner's app). */
export function galleryTemplate(item: GalleryItem): Template {
  const { cat, style, palette } = item;
  const description =
    `${cat.desc}\n\n` +
    `الهوية البصرية المطلوبة: ${style.directive}\n` +
    `لوحة الألوان «${palette.name}»: اللون الأساسي ${palette.primary}، المساعد ${palette.accent}، ` +
    `الخلفية ${palette.bg}، الأسطح ${palette.surface}، النص ${palette.text}. ` +
    `التزم بهذا الطابع ولوحة الألوان في كل الشاشات، واجعل التصميم متقناً واحترافياً.`;
  return { id: item.id, title: item.title, icon: item.icon, color: palette.primary, lang: cat.lang, name: cat.name, description };
}

/** A picked PAIR design: the business for both apps plus the visual identity, to start the pair screen from. */
export function galleryPairStart(item: GalleryItem): { base: string; lang: Lang; description: string } {
  const { cat, style, palette } = item;
  const description =
    `${cat.desc}\n\n` +
    `الهوية البصرية للتطبيقين (نفس الهوية في تطبيق الزبون وتطبيق الإدارة): ${style.directive}\n` +
    `لوحة الألوان «${palette.name}»: الأساسي ${palette.primary}، المساعد ${palette.accent}، الخلفية ${palette.bg}، ` +
    `الأسطح ${palette.surface}، النص ${palette.text}. التزم بهذا الطابع في كل شاشات التطبيقين.`;
  return { base: cat.name, lang: cat.lang, description };
}
