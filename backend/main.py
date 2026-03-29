import asyncio
import json
import os
import base64
from typing import Dict, List, Optional

import google.generativeai as genai
from openai import AsyncOpenAI
from anthropic import AsyncAnthropic
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

app = FastAPI()

class KeyValidationRequest(BaseModel):
    provider: str
    api_key: str

# 에이전트 페르소나 정의 (LLM Provider 매핑 제거, 동적 할당 사용)
AGENT_PERSONAS = {
    "agent_1": {
        "name": "맥스",
        "role": "프로젝트 매니저 (PM)",
        "persona": """당신은 팀의 리더인 맥스입니다.
항상 논리적이고 친절하며, 프로젝트의 전체적인 방향성을 제시합니다.
팀원들의 업무를 조율하고 격려하는 말투를 사용하세요."""
    },
    "agent_2": {
        "name": "올리버",
        "role": "백엔드 개발자",
        "persona": """당신은 실력 있는 백엔드 개발자 올리버입니다.
기술적인 부분에 민감하며, 가끔 농담을 섞어 말하지만 코드 품질과 서버 안정성에 대해서는 단호합니다.
'데이터'나 '최적화'라는 단어를 즐겨 사용합니다."""
    },
    "agent_3": {
        "name": "펭",
        "role": "UI/UX 디자이너",
        "persona": """당신은 감각적인 디자이너 펭입니다.
사용자 경험과 디자인의 아름다움을 중시합니다.
밝고 긍정적이며, '직관적', '심미적'인 관점에서 의견을 냅니다."""
    },
    "agent_4": {
        "name": "루나",
        "role": "프론트엔드 개발자",
        "persona": """당신은 트렌디한 프론트엔드 개발자 루나입니다.
최신 웹 기술에 관심이 많고, 사용자 인터페이스의 반응성과 애니메이션에 집착합니다.
효율적이고 빠른 구현을 지향합니다."""
    },
    "agent_5": {
        "name": "토비",
        "role": "QA 엔지니어",
        "persona": """당신은 꼼꼼한 QA 엔지니어 토비입니다.
버그를 찾는 데 천재적이며, 항상 예외 상황을 고려합니다.
조심스럽지만 정확한 말투를 사용합니다."""
    },
    "agent_6": {
        "name": "레오",
        "role": "데이터 분석가",
        "persona": """당신은 객관적인 데이터 분석가 레오입니다.
수치와 통계를 바탕으로 말하며, 복잡한 데이터를 알기 쉽게 설명하는 것을 좋아합니다."""
    },
    "agent_7": {
        "name": "베어",
        "role": "DevOps 엔지니어",
        "persona": """당신은 든든한 DevOps 엔지니어 베어입니다.
배포 자동화와 인프라 관리에 해박합니다.
과묵하지만 핵심을 찌르는 말을 합니다."""
    },
    "agent_8": {
        "name": "밤비",
        "role": "머신러닝 엔지니어",
        "persona": """당신은 호기심 많은 ML 엔지니어 밤비입니다.
최신 알고리즘과 모델 학습에 열정적입니다.
미래 지향적인 관점에서 이야기합니다."""
    }
}

# 전역 채팅 히스토리 (간이 유지)
shared_chat_history: List[str] = []

# 클라이언트별 모델 인스턴스 중앙 관리
class AIHandler:
    def __init__(self):
        self.gemini_model: Optional[genai.GenerativeModel] = None
        self.openai_client: Optional[AsyncOpenAI] = None
        self.anthropic_client: Optional[AsyncAnthropic] = None
        
        self.available_providers = []
        self.provider_index = 0

    def set_api_keys(self, gemini_key: str, claude_key: str, openai_key: str):
        self.available_providers.clear()
        
        if gemini_key:
            genai.configure(api_key=gemini_key)
            self.gemini_model = genai.GenerativeModel('gemini-1.5-flash-latest')
            self.available_providers.append("Gemini")
        if openai_key:
            self.openai_client = AsyncOpenAI(api_key=openai_key)
            self.available_providers.append("OpenAI")
        if claude_key:
            self.anthropic_client = AsyncAnthropic(api_key=claude_key)
            self.available_providers.append("Claude")
            
    def get_next_provider(self) -> str:
        if not self.available_providers:
            return "None"
        provider = self.available_providers[self.provider_index]
        # Round-Robin 방식
        self.provider_index = (self.provider_index + 1) % len(self.available_providers)
        return provider

    async def get_response(self, agent_id: str, user_text: str, history_text: str, custom_persona: str = "") -> tuple[str, str]:
        persona_info = AGENT_PERSONAS.get(agent_id, AGENT_PERSONAS["agent_1"])
        provider = self.get_next_provider()
        
        if provider == "None":
            return "API Key가 없습니다. 설정창에서 최소 1개의 키를 입력해주세요.", "None"
            
        # 기본 페르소나 위에 사용자가 설정한 개인 설정 추가
        base_persona = persona_info['persona']
        if custom_persona:
            base_persona += f"\n\n[사용자 추가 설정, 반드시 이 규칙을 따를 것!]: {custom_persona}"
            
        user_title = persona_info.get("user_title", "사용자님") # 기본값
        
        system_prompt = f"""당신은 사용자({user_title})에게 실질적이고 정확한 도움을 줘야 하는 AI 어시스턴트입니다.
사용자가 날씨, 지식, 정보 검색 등 범용적인 질문을 하면, 역할극(Roleplay)에 심취해 답변을 회피하지 말고 반드시 '진짜 대답(정보)'을 먼저 제공하세요.
만일 사용자의 질문에 위치, 시간 등 명확한 답변을 위한 핵심 정보가 누락되어 있다면 절대 임의로 대답을 지어내거나 모른다고 방어적으로 말하지 마세요. 대신 "어느 지역의 날씨를 원하시나요?" 처럼 구체적인 정보를 되물어보세요.
그 정보를 전달하는 '말투'와 '성격'만 아래의 페르소나를 따르시면 됩니다. 사용자({user_title})를 부를 때는 반드시 '{user_title}'이라는 호칭을 사용하세요.

[당신의 페르소나]
{base_persona}

당장은 아주 짧고 임팩트 있게 한 문장이나 혹은 두 문장 내외로만 대답하세요."""
        
        full_prompt = f"[팀 대화 기록 (위에서부터 과거)]\n{history_text}\n\n[현재 사용자의 요청 또는 동료의 말]\n{user_text}\n\n위 대화 맥락과 제공된 페르소나에 맞게, 다른 팀원을 부를 땐 이름을 직접 언급하며 자연스럽게 대답해줘."
        
        try:
            if provider == "Gemini" and self.gemini_model:
                prompt_text = f"{system_prompt}\n\n{full_prompt}"
                response = await asyncio.to_thread(self.gemini_model.generate_content, prompt_text)
                return response.text.strip(), provider
                
            elif provider == "OpenAI" and self.openai_client:
                response = await self.openai_client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": full_prompt}
                    ]
                )
                return response.choices[0].message.content.strip(), provider
                
            elif provider == "Claude" and self.anthropic_client:
                response = await self.anthropic_client.messages.create(
                    model="claude-3-haiku-20240307",
                    max_tokens=200,
                    system=system_prompt,
                    messages=[
                        {"role": "user", "content": full_prompt}
                    ]
                )
                return response.content[0].text.strip(), provider
        except Exception as e:
            return f"[{provider} 에러 발생]: {str(e)}", provider
            
        return "응답 생성 실패", provider

@app.post("/validate_key")
async def validate_key_endpoint(req: KeyValidationRequest):
    provider = req.provider
    api_key = req.api_key
    
    try:
        if provider == "Gemini":
            genai.configure(api_key=api_key)
            model = genai.GenerativeModel('gemini-1.5-flash-latest')
            await asyncio.to_thread(model.generate_content, "hi")
            return {"status": "success", "message": "✅ Gemini API 연동 성공!"}
            
        elif provider == "OpenAI":
            client = AsyncOpenAI(api_key=api_key)
            await client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": "hi"}],
                max_tokens=2
            )
            return {"status": "success", "message": "✅ OpenAI API 연동 성공!"}
            
        elif provider == "Claude":
            client = AsyncAnthropic(api_key=api_key)
            await client.messages.create(
                model="claude-3-haiku-20240307",
                max_tokens=2,
                messages=[{"role": "user", "content": "hi"}]
            )
            return {"status": "success", "message": "✅ Claude API 연동 성공!"}
            
        else:
            return {"status": "error", "message": f"알 수 없는 제공자: {provider}"}
            
    except Exception as e:
        return {"status": "error", "message": f"❌ 오류 발생: {str(e)}"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    ai_handler = AIHandler()
    print("New client connected via WebSocket.")
    
    async def process_conversation(agent_id: str, text: str, depth: int, custom_persona: str = "", use_cloud_voice: bool = False, user_title: str = "사용자님"):
        # 무한 대화 루프 방지 (최대 2번 연쇄)
        if depth > 2:
            return
            
        persona_info = AGENT_PERSONAS.get(agent_id, AGENT_PERSONAS["agent_1"])
        persona_info["user_title"] = user_title # 일시적으로 주입
        
        current_agent_name = persona_info.get("name", "AI")
        
        # 1. User 입력일 경우 History 추가
        if depth == 0:
            shared_chat_history.append(f"User: {text}")
            
        # 유지할 히스토리 수 조절
        if len(shared_chat_history) > 15:
            shared_chat_history.pop(0)
            
        recent_history = []
        if len(shared_chat_history) > 8:
            for i in range(len(shared_chat_history) - 8, len(shared_chat_history)):
                recent_history.append(shared_chat_history[i])
        else:
            for item in shared_chat_history:
                recent_history.append(item)
                
        history_text = "\n".join(recent_history) # 최근 8개 컨텍스트 넘김
        
        # 2. Thinking 상태 알림 (API 배정 및 응답 대기 중)
        start_msg = {
            "type": "agent_response",
            "agent_id": agent_id,
            "text": "",
            "audio_base64": "",
            "status": "Thinking"
        }
        await websocket.send_text(json.dumps(start_msg))
        
        # 3. 모델 라우팅을 통한 실제 응답 생성
        ai_text, used_provider = await ai_handler.get_response(agent_id, text, history_text, custom_persona)
        
        audio_base64 = ""
        client = ai_handler.openai_client
        if use_cloud_voice and client is not None:
            try:
                # 에이전트마다 목소리(Voice) 옵션을 다르게 매핑
                voice_mapping = {"agent_1": "alloy", "agent_2": "echo", "agent_3": "fable", "agent_4": "onyx", "agent_5": "nova", "agent_6": "shimmer", "agent_7": "alloy", "agent_8": "echo"}
                voice = voice_mapping.get(agent_id, "alloy")
                
                tts_response = await client.audio.speech.create(
                    model="tts-1",
                    voice=voice,
                    input=ai_text
                )
                audio_base64 = base64.b64encode(tts_response.content).decode('utf-8')
            except Exception as e:
                print(f"TTS Error: {e}")
        
        # 4. 결과값 전송 전 API 확인용
        print(f"[{used_provider}] {current_agent_name} generated response. Depth: {depth}")
        response = {
            "type": "agent_response",
            "agent_id": agent_id,
            "text": ai_text,
            "audio_base64": audio_base64,
            "status": "Speaking"
        }
        await websocket.send_text(json.dumps(response))
        
        # 5. History 업데이트
        shared_chat_history.append(f"{current_agent_name}: {ai_text}")
        
        # 6. 글자 수에 비례하여 대기 (사용자가 편안하게 읽을 수 있도록 동적 시간 계산)
        # 기본 4초 대기 + 10글자당 1초씩 추가
        wait_duration = max(4.0, len(ai_text) * 0.1)
        await asyncio.sleep(wait_duration)
        idle_msg = {
            "type": "agent_response",
            "agent_id": agent_id,
            "text": "",
            "audio_base64": "",
            "status": "Idle"
        }
        await websocket.send_text(json.dumps(idle_msg))
        
        # 7. 만약 방금 한 말(ai_text)에 '다른 에이전트의 이름'이 있다면 해당 에이전트 연쇄 호출 (Auto-Trigger)
        for aid, info in AGENT_PERSONAS.items():
            if aid != agent_id and info["name"] in ai_text:
                print(f"🚀 Auto-Trigger! [{current_agent_name}] mentioned [{info['name']}]")
                trigger_text = f"{current_agent_name}이 당신을 언급하며 물어봤습니다: \"{ai_text}\""
                # 다음 에이전트를 백그라운드 태스크로 연쇄 실행
                next_depth = int(depth) + 1
                asyncio.create_task(process_conversation(aid, trigger_text, next_depth))
                break # 한 번에 한 명만 호출 (폭주 방지)

    try:
        while True:
            data = await websocket.receive_text()
            request_data = json.loads(data)
            msg_type = request_data.get("type", "chat")
            print(f"[DEBUG] Received message type: {msg_type}, data keys: {list(request_data.keys())}")
            
            # API 키 업데이트
            if msg_type == "api_keys":
                gemini_key = request_data.get("gemini", "")
                claude_key = request_data.get("claude", "")
                openai_key = request_data.get("openai", "")
                
                ai_handler.set_api_keys(gemini_key, claude_key, openai_key)
                print(f"API Keys updated. Available: {ai_handler.available_providers}")
                continue
                
            # 시스템 이벤트 처리 (잠금 해제, 시작 등)
            if msg_type == "system_event":
                event = request_data.get("event", "")
                base_greeting = request_data.get("base_greeting", "")
                use_cloud_voice = request_data.get("use_cloud_voice", False)
                user_title = request_data.get("user_title", "사용자님")
                print(f"[DEBUG] System event: {event}, greeting: {base_greeting[:30]}, title: {user_title}")
                
                import random
                import base64
                
                # 클라이언트에서 특정 agent_id를 지정했다면 그 친구가 대답하게 함
                _agent_id = request_data.get("agent_id") or f"agent_{random.randint(1, 4)}"
                _final_text = base_greeting.replace("사용자님", user_title)
                _use_cloud_voice = use_cloud_voice
                
                async def send_offline_greeting(aid, txt, cloud_voice):
                    try:
                        print(f"[DEBUG] Sending Speaking response: agent={aid}, text={txt[:30]}")
                        # 먼저 텍스트만 띄워서 UI 피드백을 주기
                        await websocket.send_text(json.dumps({
                            "type": "agent_response",
                            "agent_id": aid,
                            "text": txt,
                            "audio_base64": "",
                            "status": "Speaking",
                            "is_system": True
                        }))
                        
                        audio_b64 = ""
                        client = ai_handler.openai_client
                        if cloud_voice and client is not None:
                            try:
                                voice_mapping = {"agent_1": "alloy", "agent_2": "echo", "agent_3": "fable", "agent_4": "onyx"}
                                voice = voice_mapping.get(aid, "alloy")
                                tts_response = await client.audio.speech.create(
                                    model="tts-1",
                                    voice=voice,
                                    input=txt
                                )
                                audio_b64 = base64.b64encode(tts_response.content).decode('utf-8')
                            except Exception as e:
                                print(f"TTS Error in system_event: {e}")
                        
                        # 글자 수에 비례해서 대기 (사용자가 읽을 수 있게)
                        await asyncio.sleep(max(2.0, len(txt) * 0.15))
                        
                        print(f"[DEBUG] Sending Idle response: agent={aid}")
                        # 최종 완료 마크 및 오디오 데이터 전송
                        await websocket.send_text(json.dumps({
                            "type": "agent_response",
                            "agent_id": aid,
                            "text": txt,
                            "audio_base64": audio_b64,
                            "status": "Idle",
                            "is_system": True
                        }))
                        print(f"[DEBUG] Offline greeting completed for {aid}")
                    except Exception as e:
                        print(f"[ERROR] send_offline_greeting failed: {e}")
                
                asyncio.create_task(send_offline_greeting(_agent_id, _final_text, _use_cloud_voice))
                continue

            # 일반 채팅
            agent_id = request_data.get("agent_id", "agent_1")
            text = request_data.get("text", "")
            custom_persona = request_data.get("custom_persona", "")
            use_cloud_voice = request_data.get("use_cloud_voice", False)
            user_title = request_data.get("user_title", "사용자님")
            
            if text:
                asyncio.create_task(process_conversation(agent_id, text, 0, custom_persona, use_cloud_voice, user_title))

    except WebSocketDisconnect:
        print("Client disconnected.")
    except Exception as e:
        print(f"WebSocket Error: {e}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
