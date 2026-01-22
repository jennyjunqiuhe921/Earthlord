// supabase/functions/generate-ai-item/index.ts
// AI 物品生成 Edge Function
// 使用阿里云百炼 qwen-flash 模型生成独特的游戏物品

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// 阿里云百炼配置（使用国际版端点）
const DASHSCOPE_API_KEY = Deno.env.get("DASHSCOPE_API_KEY");
const DASHSCOPE_BASE_URL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions";

// 系统提示词
const SYSTEM_PROMPT = `你是一个末日生存游戏的物品生成器。游戏背景是丧尸末日后的世界。

根据玩家搜刮的地点，生成符合场景的物品列表。每个物品包含：
- name: 独特的物品名称（15字以内），可以暗示前主人身份或物品来历
- category: 分类（医疗/食物/工具/武器/材料）
- rarity: 稀有度（common/uncommon/rare/epic/legendary）
- story: 背景故事（50-100字），要有画面感，营造末日氛围

生成规则：
1. 物品类型必须与搜刮地点相关（医院出医疗物品，超市出食物等）
2. 名称要有创意，可以用「」包裹特殊名称
3. 故事要简短有画面感，可以有黑色幽默，但不要太血腥
4. 稀有度越高，名称越独特，故事越精彩
5. 每个物品的故事都应该不同，展现末日世界的多样性

风格参考：
- 普通物品：朴实的名称，简单的来历
- 稀有物品：带有前主人痕迹的名称
- 史诗物品：有故事性的独特名称
- 传奇物品：带有传说色彩的名称

只返回 JSON 数组格式，不要包含任何其他文字或解释。`;

// 根据危险值获取稀有度分布权重
function getRarityWeights(dangerLevel: number): Record<string, number> {
    switch (dangerLevel) {
        case 1:
        case 2:
            return { common: 70, uncommon: 25, rare: 5, epic: 0, legendary: 0 };
        case 3:
            return { common: 50, uncommon: 30, rare: 15, epic: 5, legendary: 0 };
        case 4:
            return { common: 0, uncommon: 40, rare: 35, epic: 20, legendary: 5 };
        case 5:
            return { common: 0, uncommon: 0, rare: 30, epic: 40, legendary: 30 };
        default:
            return { common: 60, uncommon: 30, rare: 10, epic: 0, legendary: 0 };
    }
}

// POI 类型到物品分类的映射
function getExpectedCategories(poiType: string): string {
    const categoryMap: Record<string, string> = {
        "hospital": "主要生成医疗物品，少量食物",
        "pharmacy": "主要生成医疗物品（药品为主）",
        "supermarket": "主要生成食物和日用品",
        "convenience_store": "主要生成食物和饮料",
        "restaurant": "主要生成食物",
        "gas_station": "主要生成工具和燃料相关物品",
        "hardware": "主要生成工具和材料",
        "police_station": "主要生成武器和防护装备",
        "military": "主要生成武器和高级装备",
        "residential": "各类日用品、食物",
        "school": "文具、食物、少量工具",
        "factory": "主要生成材料和工具",
        "warehouse": "各类物资，可能有惊喜"
    };
    return categoryMap[poiType] || "各类末日生存物资";
}

// 主处理函数
Deno.serve(async (req: Request) => {
    // 处理 CORS 预检请求
    if (req.method === "OPTIONS") {
        return new Response(null, {
            status: 204,
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization",
            },
        });
    }

    try {
        // 检查 API Key
        if (!DASHSCOPE_API_KEY) {
            console.error("[generate-ai-item] DASHSCOPE_API_KEY not configured");
            return new Response(
                JSON.stringify({
                    success: false,
                    error: "AI service not configured",
                    items: []
                }),
                {
                    status: 500,
                    headers: {
                        "Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"
                    }
                }
            );
        }

        // 解析请求
        const { poi, itemCount = 3 } = await req.json();

        if (!poi || !poi.name || !poi.type) {
            return new Response(
                JSON.stringify({
                    success: false,
                    error: "Invalid POI data",
                    items: []
                }),
                {
                    status: 400,
                    headers: {
                        "Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"
                    }
                }
            );
        }

        console.log(`[generate-ai-item] Generating ${itemCount} items for POI: ${poi.name} (${poi.type}, danger: ${poi.dangerLevel})`);

        // 获取稀有度分布
        const rarityWeights = getRarityWeights(poi.dangerLevel || 1);
        const expectedCategories = getExpectedCategories(poi.type);

        // 构建用户提示词
        const userPrompt = `搜刮地点：${poi.name}
地点类型：${poi.type}
危险等级：${poi.dangerLevel || 1}/5

请生成 ${itemCount} 个物品。

物品分类要求：${expectedCategories}

稀有度分布参考（请严格遵守）：
- 普通(common): ${rarityWeights.common}%
- 优秀(uncommon): ${rarityWeights.uncommon}%
- 稀有(rare): ${rarityWeights.rare}%
- 史诗(epic): ${rarityWeights.epic}%
- 传奇(legendary): ${rarityWeights.legendary}%

返回格式示例：
[
  {
    "name": "物品名称",
    "category": "食物",
    "rarity": "common",
    "story": "这个物品的背景故事..."
  }
]

只返回 JSON 数组，不要其他内容。`;

        // 调用阿里云百炼 API
        const response = await fetch(DASHSCOPE_BASE_URL, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${DASHSCOPE_API_KEY}`,
            },
            body: JSON.stringify({
                model: "qwen-turbo",
                messages: [
                    { role: "system", content: SYSTEM_PROMPT },
                    { role: "user", content: userPrompt }
                ],
                max_tokens: 1500,
                temperature: 0.8,
            }),
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error(`[generate-ai-item] AI API error: ${response.status} - ${errorText}`);
            return new Response(
                JSON.stringify({
                    success: false,
                    error: `AI API error: ${response.status}`,
                    items: []
                }),
                {
                    status: 500,
                    headers: {
                        "Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"
                    }
                }
            );
        }

        const data = await response.json();
        const content = data.choices?.[0]?.message?.content;

        if (!content) {
            console.error("[generate-ai-item] Empty response from AI");
            return new Response(
                JSON.stringify({
                    success: false,
                    error: "Empty AI response",
                    items: []
                }),
                {
                    status: 500,
                    headers: {
                        "Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"
                    }
                }
            );
        }

        // 解析 AI 返回的 JSON
        let items;
        try {
            // 尝试直接解析
            items = JSON.parse(content);
        } catch {
            // 如果失败，尝试提取 JSON 部分
            const jsonMatch = content.match(/\[[\s\S]*\]/);
            if (jsonMatch) {
                items = JSON.parse(jsonMatch[0]);
            } else {
                throw new Error("Cannot parse AI response as JSON");
            }
        }

        // 验证并清理物品数据
        const validatedItems = items.map((item: any, index: number) => ({
            name: item.name || `未知物品 ${index + 1}`,
            category: item.category || "材料",
            rarity: ["common", "uncommon", "rare", "epic", "legendary"].includes(item.rarity)
                ? item.rarity
                : "common",
            story: item.story || "一个在末日中发现的物品。"
        }));

        console.log(`[generate-ai-item] Successfully generated ${validatedItems.length} items`);

        return new Response(
            JSON.stringify({
                success: true,
                items: validatedItems,
                poi: {
                    name: poi.name,
                    type: poi.type,
                    dangerLevel: poi.dangerLevel
                }
            }),
            {
                headers: {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                }
            }
        );

    } catch (error) {
        console.error("[generate-ai-item] Error:", error);
        return new Response(
            JSON.stringify({
                success: false,
                error: error instanceof Error ? error.message : "Unknown error",
                items: []
            }),
            {
                status: 500,
                headers: {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                }
            }
        );
    }
});
