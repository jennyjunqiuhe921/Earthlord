“-- 物品定义表完整迁移脚本
-- 创建时间: 2026-01-26
-- 用途: 添加所有游戏物品定义，支持探索、交易、建造系统

-- 1. 创建 item_definitions 表（如果不存在）
CREATE TABLE IF NOT EXISTS public.item_definitions (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('water', 'food', 'medical', 'material', 'tool', 'weapon')),
    rarity TEXT NOT NULL CHECK (rarity IN ('common', 'uncommon', 'rare', 'epic', 'legendary')),
    weight NUMERIC DEFAULT 0,
    description TEXT,
    icon_name TEXT,
    can_stack BOOLEAN DEFAULT true,
    max_stack INTEGER DEFAULT 99,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 2. 启用 RLS
ALTER TABLE public.item_definitions ENABLE ROW LEVEL SECURITY;

-- 3. 所有人可读取物品定义
DROP POLICY IF EXISTS "Item definitions are viewable by everyone" ON public.item_definitions;
CREATE POLICY "Item definitions are viewable by everyone"
    ON public.item_definitions FOR SELECT
    USING (true);

-- 4. 确保 inventory_items 表有 AI 自定义字段
ALTER TABLE public.inventory_items
    ADD COLUMN IF NOT EXISTS custom_name TEXT,
    ADD COLUMN IF NOT EXISTS custom_story TEXT,
    ADD COLUMN IF NOT EXISTS custom_category TEXT,
    ADD COLUMN IF NOT EXISTS custom_rarity TEXT;

-- 5. 插入/更新物品定义（使用 upsert 避免重复）
-- ==================== 水类物品 ====================
INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_water', '矿泉水', 'water', 'common', 500, '普通的瓶装矿泉水，可以补充水分', 'drop.fill', true, 20)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

-- item_water_bottle 是 item_water 的别名，保持兼容性
INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_water_bottle', '矿泉水', 'water', 'common', 500, '500ml瓶装矿泉水，末日中最珍贵的资源之一', 'drop.fill', true, 20)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_purified_water', '净化水', 'water', 'uncommon', 500, '经过净化的饮用水，更加安全', 'drop.circle.fill', true, 20)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity;

-- ==================== 食物类物品 ====================
INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_biscuit', '饼干', 'food', 'common', 100, '普通的压缩饼干，可以充饥', 'birthday.cake.fill', true, 30)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_canned_food', '罐头食品', 'food', 'uncommon', 300, '保质期很长的罐装食品', 'takeoutbag.and.cup.and.straw.fill', true, 20)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_energy_bar', '能量棒', 'food', 'common', 80, '高能量的营养棒，快速补充体力', 'bolt.fill', true, 30)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_mre', '军用口粮', 'food', 'rare', 500, '军用即食口粮，营养均衡', 'fork.knife', true, 10)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

-- ==================== 医疗类物品 ====================
INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_bandage', '绷带', 'medical', 'common', 50, '普通的医用绷带，可以包扎伤口', 'bandage.fill', true, 20)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_first_aid_kit', '急救包', 'medical', 'rare', 500, '包含基本急救用品的医疗包', 'cross.case.fill', true, 5)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_antibiotics', '抗生素', 'medical', 'epic', 100, '珍贵的抗生素药物，可以治疗感染', 'pills.fill', true, 10)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_painkillers', '止痛药', 'medical', 'uncommon', 50, '可以缓解疼痛的药物', 'pill.fill', true, 15)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

-- item_medicine 是 item_antibiotics 的别名，保持兼容性
INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_medicine', '抗生素药品', 'medical', 'uncommon', 100, '广谱抗生素，可治疗感染和疾病。非常珍贵。', 'pills.fill', true, 10)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_surgical_kit', '手术套件', 'medical', 'legendary', 1000, '完整的手术工具，可以进行复杂的医疗操作', 'stethoscope', true, 1)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

-- ==================== 工具类物品 ====================
INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_matches', '火柴', 'tool', 'common', 20, '一盒普通火柴，可以生火', 'flame.fill', true, 50)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_flashlight', '手电筒', 'tool', 'rare', 200, '便携式手电筒，黑暗中的好帮手', 'flashlight.on.fill', true, 5)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_gas_mask', '防毒面具', 'tool', 'epic', 500, '可以过滤有毒气体的面具', 'facemask.fill', true, 3)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_toolbox', '工具箱', 'tool', 'rare', 2000, '包含各种维修工具的工具箱', 'wrench.and.screwdriver.fill', true, 3)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_rope', '绳索', 'tool', 'common', 500, '结实的尼龙绳，多种用途', 'lasso', true, 10)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_compass', '指南针', 'tool', 'uncommon', 50, '可靠的导航工具', 'safari.fill', true, 5)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_radio', '对讲机', 'tool', 'rare', 300, '可以进行短距离通讯', 'antenna.radiowaves.left.and.right', true, 3)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

-- ==================== 材料类物品 ====================
INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_wood', '木头', 'material', 'common', 1000, '普通的木材，建造的基础材料', 'leaf.fill', true, 100)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_stone', '石头', 'material', 'common', 2000, '坚硬的石块，建造的基础材料', 'cube.fill', true, 100)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_metal_scrap', '金属碎片', 'material', 'uncommon', 500, '可回收利用的金属碎片', 'gearshape.fill', true, 50)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_cloth', '布料', 'material', 'common', 200, '可用于制作各种物品的布料', 'rectangle.split.3x3.fill', true, 50)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_electronics', '电子元件', 'material', 'rare', 100, '各种电子设备的零部件', 'cpu.fill', true, 30)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_generator_parts', '发电机零件', 'material', 'epic', 3000, '稀有的发电机维修零件', 'bolt.circle.fill', true, 10)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    weight = EXCLUDED.weight,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_fuel', '燃料', 'material', 'uncommon', 1000, '可燃的燃料，用于各种设备', 'fuelpump.fill', true, 20)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

-- ==================== 武器类物品 ====================
INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_knife', '小刀', 'weapon', 'common', 200, '锋利的小刀，可用于切割和自卫', 'scissors', true, 5)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_bat', '棒球棒', 'weapon', 'uncommon', 1000, '结实的棒球棒，近战武器', 'figure.baseball', true, 3)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

INSERT INTO public.item_definitions (id, name, category, rarity, weight, description, icon_name, can_stack, max_stack)
VALUES
    ('item_axe', '斧头', 'weapon', 'rare', 1500, '锋利的斧头，可以砍伐和战斗', 'hammer.fill', true, 2)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category;

-- 6. 创建索引
CREATE INDEX IF NOT EXISTS idx_item_definitions_category ON public.item_definitions(category);
CREATE INDEX IF NOT EXISTS idx_item_definitions_rarity ON public.item_definitions(rarity);

-- 7. 添加注释
COMMENT ON TABLE public.item_definitions IS '物品定义表 - 存储所有游戏物品的基础信息';
COMMENT ON COLUMN public.item_definitions.id IS '物品唯一标识符（如 item_water）';
COMMENT ON COLUMN public.item_definitions.name IS '物品中文名称';
COMMENT ON COLUMN public.item_definitions.category IS '物品分类：water/food/medical/material/tool/weapon';
COMMENT ON COLUMN public.item_definitions.rarity IS '稀有度：common/uncommon/rare/epic/legendary';
COMMENT ON COLUMN public.item_definitions.weight IS '重量（克）';
COMMENT ON COLUMN public.item_definitions.icon_name IS 'SF Symbols 图标名称';
COMMENT ON COLUMN public.item_definitions.can_stack IS '是否可堆叠';
COMMENT ON COLUMN public.item_definitions.max_stack IS '最大堆叠数量';

-- 完成提示
-- SELECT '物品定义迁移完成！共插入 ' || COUNT(*) || ' 个物品' as result FROM public.item_definitions;
”
