-- 地球新主游戏核心数据表
-- 创建时间: 2025-12-26

-- 1. 创建 profiles 表（用户资料）
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 2. 创建 territories 表（领地）
CREATE TABLE IF NOT EXISTS public.territories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    path JSONB NOT NULL,
    area NUMERIC NOT NULL CHECK (area > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 3. 创建 pois 表（兴趣点）
CREATE TABLE IF NOT EXISTS public.pois (
    id TEXT PRIMARY KEY,
    poi_type TEXT NOT NULL CHECK (poi_type IN ('hospital', 'supermarket', 'factory', 'school', 'park', 'other')),
    name TEXT NOT NULL,
    latitude NUMERIC NOT NULL CHECK (latitude >= -90 AND latitude <= 90),
    longitude NUMERIC NOT NULL CHECK (longitude >= -180 AND longitude <= 180),
    discovered_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    discovered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 创建索引以优化查询性能
CREATE INDEX IF NOT EXISTS idx_territories_user_id ON public.territories(user_id);
CREATE INDEX IF NOT EXISTS idx_territories_created_at ON public.territories(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pois_type ON public.pois(poi_type);
CREATE INDEX IF NOT EXISTS idx_pois_location ON public.pois(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_pois_discovered_by ON public.pois(discovered_by);

-- 启用 Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pois ENABLE ROW LEVEL SECURITY;

-- Profiles 表的 RLS 策略
-- 用户可以查看所有用户的资料
CREATE POLICY "Profiles are viewable by everyone"
    ON public.profiles FOR SELECT
    USING (true);

-- 用户只能插入自己的资料
CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- 用户只能更新自己的资料
CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Territories 表的 RLS 策略
-- 所有人可以查看所有领地
CREATE POLICY "Territories are viewable by everyone"
    ON public.territories FOR SELECT
    USING (true);

-- 用户只能创建属于自己的领地
CREATE POLICY "Users can insert their own territories"
    ON public.territories FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 用户只能更新自己的领地
CREATE POLICY "Users can update their own territories"
    ON public.territories FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 用户只能删除自己的领地
CREATE POLICY "Users can delete their own territories"
    ON public.territories FOR DELETE
    USING (auth.uid() = user_id);

-- POIs 表的 RLS 策略
-- 所有人可以查看所有 POI
CREATE POLICY "POIs are viewable by everyone"
    ON public.pois FOR SELECT
    USING (true);

-- 任何认证用户都可以添加新的 POI
CREATE POLICY "Authenticated users can insert POIs"
    ON public.pois FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- 只有发现者可以更新 POI
CREATE POLICY "Discoverers can update their POIs"
    ON public.pois FOR UPDATE
    USING (auth.uid() = discovered_by)
    WITH CHECK (auth.uid() = discovered_by);

-- 只有发现者可以删除 POI
CREATE POLICY "Discoverers can delete their POIs"
    ON public.pois FOR DELETE
    USING (auth.uid() = discovered_by);

-- 创建触发器：当新用户注册时自动创建 profile
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substr(NEW.id::text, 1, 8)),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 绑定触发器到 auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 添加注释说明
COMMENT ON TABLE public.profiles IS '用户资料表';
COMMENT ON TABLE public.territories IS '用户领地表';
COMMENT ON TABLE public.pois IS '兴趣点表';

COMMENT ON COLUMN public.profiles.id IS '用户ID，关联 auth.users';
COMMENT ON COLUMN public.profiles.username IS '用户名，唯一';
COMMENT ON COLUMN public.profiles.avatar_url IS '头像 URL';

COMMENT ON COLUMN public.territories.user_id IS '领地所有者ID';
COMMENT ON COLUMN public.territories.name IS '领地名称';
COMMENT ON COLUMN public.territories.path IS '领地边界路径点数组（JSONB格式）';
COMMENT ON COLUMN public.territories.area IS '领地面积（平方米）';

COMMENT ON COLUMN public.pois.id IS '兴趣点外部ID';
COMMENT ON COLUMN public.pois.poi_type IS 'POI类型：hospital, supermarket, factory 等';
COMMENT ON COLUMN public.pois.latitude IS '纬度';
COMMENT ON COLUMN public.pois.longitude IS '经度';
COMMENT ON COLUMN public.pois.discovered_by IS '发现者用户ID';
