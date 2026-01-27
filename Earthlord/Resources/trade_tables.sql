-- =====================================================
-- 交易系统数据库表
-- Earthlord - 地球新主
--
-- 请在 Supabase SQL Editor 中运行此脚本
-- =====================================================

-- -----------------------------------------------------
-- 1. 交易挂单表 (trade_offers)
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS trade_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    owner_username TEXT,
    offering_items JSONB NOT NULL DEFAULT '[]',
    requesting_items JSONB NOT NULL DEFAULT '[]',
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled', 'expired')),
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    completed_by_user_id UUID REFERENCES auth.users(id),
    completed_by_username TEXT
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_trade_offers_owner_id ON trade_offers(owner_id);
CREATE INDEX IF NOT EXISTS idx_trade_offers_status ON trade_offers(status);
CREATE INDEX IF NOT EXISTS idx_trade_offers_expires_at ON trade_offers(expires_at);
CREATE INDEX IF NOT EXISTS idx_trade_offers_created_at ON trade_offers(created_at DESC);

-- 注释
COMMENT ON TABLE trade_offers IS '交易挂单表 - 存储用户发布的交易请求';
COMMENT ON COLUMN trade_offers.offering_items IS '提供的物品列表，JSON格式：[{"item_id": "xxx", "quantity": 10}]';
COMMENT ON COLUMN trade_offers.requesting_items IS '需要的物品列表，JSON格式同上';
COMMENT ON COLUMN trade_offers.status IS '状态：active(等待中), completed(已完成), cancelled(已取消), expired(已过期)';

-- -----------------------------------------------------
-- 2. 交易历史表 (trade_history)
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS trade_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id UUID REFERENCES trade_offers(id) ON DELETE SET NULL,
    seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    seller_username TEXT,
    buyer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    buyer_username TEXT,
    items_exchanged JSONB NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    seller_rating INTEGER CHECK (seller_rating >= 1 AND seller_rating <= 5),
    buyer_rating INTEGER CHECK (buyer_rating >= 1 AND buyer_rating <= 5),
    seller_comment TEXT,
    buyer_comment TEXT
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_trade_history_seller_id ON trade_history(seller_id);
CREATE INDEX IF NOT EXISTS idx_trade_history_buyer_id ON trade_history(buyer_id);
CREATE INDEX IF NOT EXISTS idx_trade_history_completed_at ON trade_history(completed_at DESC);

-- 注释
COMMENT ON TABLE trade_history IS '交易历史表 - 记录所有已完成的交易';
COMMENT ON COLUMN trade_history.items_exchanged IS '交换详情，JSON格式：{"seller_gave": [...], "buyer_gave": [...]}';
COMMENT ON COLUMN trade_history.seller_rating IS '卖家给买家的评分(1-5)';
COMMENT ON COLUMN trade_history.buyer_rating IS '买家给卖家的评分(1-5)';

-- -----------------------------------------------------
-- 3. 行级安全策略 (RLS)
-- -----------------------------------------------------

-- 启用 RLS
ALTER TABLE trade_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE trade_history ENABLE ROW LEVEL SECURITY;

-- trade_offers 策略

-- 所有登录用户可以查看活跃的挂单
CREATE POLICY "Anyone can view active trade offers"
ON trade_offers FOR SELECT
TO authenticated
USING (status = 'active' AND expires_at > NOW());

-- 用户可以查看自己的所有挂单
CREATE POLICY "Users can view own trade offers"
ON trade_offers FOR SELECT
TO authenticated
USING (owner_id = auth.uid());

-- 用户可以创建挂单
CREATE POLICY "Users can create trade offers"
ON trade_offers FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

-- 用户可以更新自己的挂单（取消）
CREATE POLICY "Users can update own trade offers"
ON trade_offers FOR UPDATE
TO authenticated
USING (owner_id = auth.uid() OR completed_by_user_id = auth.uid());

-- trade_history 策略

-- 用户只能查看自己参与的交易历史
CREATE POLICY "Users can view own trade history"
ON trade_history FOR SELECT
TO authenticated
USING (seller_id = auth.uid() OR buyer_id = auth.uid());

-- 系统可以创建交易历史（通过服务端）
CREATE POLICY "Users can create trade history"
ON trade_history FOR INSERT
TO authenticated
WITH CHECK (seller_id = auth.uid() OR buyer_id = auth.uid());

-- 用户可以更新自己的评价
CREATE POLICY "Users can update own ratings"
ON trade_history FOR UPDATE
TO authenticated
USING (seller_id = auth.uid() OR buyer_id = auth.uid());

-- -----------------------------------------------------
-- 4. 完成提示
-- -----------------------------------------------------

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '交易系统数据库表创建完成！';
    RAISE NOTICE '';
    RAISE NOTICE '已创建的表：';
    RAISE NOTICE '  - trade_offers: 交易挂单表';
    RAISE NOTICE '  - trade_history: 交易历史表';
    RAISE NOTICE '';
    RAISE NOTICE '已启用行级安全策略(RLS)';
    RAISE NOTICE '========================================';
END $$;
