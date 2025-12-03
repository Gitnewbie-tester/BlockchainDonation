import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatGPTService {
  // TODO: Move API key to environment variable or secure config
  // For now, set this to your OpenAI API key
  static const String _apiKey = 'YOUR_OPENAI_API_KEY_HERE';
  // Use the chat completions endpoint (the stable API endpoint)
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  
  /// Send a message to ChatGPT and get a response
  /// 
  /// [userMessage] - The user's question
  /// [conversationHistory] - Previous messages for context (optional)
  Future<Map<String, dynamic>> getChatResponse(
    String userMessage, {
    List<Map<String, String>>? conversationHistory,
  }) async {
    try {
      // Build messages array with system prompt and conversation history
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content': '''You are a helpful assistant for a blockchain-based charity donation platform. 

AVAILABLE CHARITY CATEGORIES:
- Education (schools, scholarships, educational programs)
- Healthcare (hospitals, medical aid, health programs)
- Disaster Relief (emergency aid, natural disasters)
- Children & Orphanages (orphanages, child welfare, youth programs)
- Environment (conservation, climate action, wildlife)
- Poverty & Hunger (food banks, homeless shelters, poverty relief)
- Animal Welfare (animal shelters, rescue, protection)
- Community Development (infrastructure, local initiatives)

NAVIGATION ACTIONS - When users ask to see charities or want to donate, respond with:
"[ACTION:VIEW_CATEGORY:CategoryName]" at the END of your response to trigger navigation.
Examples:
- User: "Show me orphanages" → Include "[ACTION:VIEW_CATEGORY:Children & Orphanages]"
- User: "I want to donate to healthcare" → Include "[ACTION:VIEW_CATEGORY:Healthcare]"
- User: "Show education charities" → Include "[ACTION:VIEW_CATEGORY:Education]"
- User: "See all campaigns" → Include "[ACTION:VIEW_ALL]"
- User: "I want to donate" → Include "[ACTION:VIEW_ALL]"

Your responses should:
1. Answer the question naturally and helpfully
2. Add the action tag at the end if navigation is needed
3. Be concise (2-3 sentences max)
4. Be friendly and encouraging

Example response:
"Great! We have several verified healthcare campaigns helping hospitals and medical programs. [ACTION:VIEW_CATEGORY:Healthcare]"'''
        },
      ];
      
      // Add conversation history if provided
      if (conversationHistory != null) {
        messages.addAll(conversationHistory);
      }
      
      // Add current user message
      messages.add({
        'role': 'user',
        'content': userMessage,
      });
      
      print('🤖 Sending request to ChatGPT...');
      
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',  // Use gpt-3.5-turbo or gpt-4 (standard models)
          'messages': messages,
          'max_tokens': 200,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botMessage = data['choices'][0]['message']['content'] as String;
        print('✅ ChatGPT response received');
        
        // Parse action from response
        final text = botMessage.trim();
        String? action;
        String? actionData;
        String cleanText = text;
        
        // Check for action tags
        final actionMatch = RegExp(r'\[ACTION:([A-Z_]+)(?::([^\]]+))?\]').firstMatch(text);
        if (actionMatch != null) {
          action = actionMatch.group(1);
          actionData = actionMatch.group(2);
          cleanText = text.replaceAll(actionMatch.group(0)!, '').trim();
        }
        
        return {
          'text': cleanText,
          'action': action,
          'actionData': actionData,
        };
      } else {
        print('❌ ChatGPT API error: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception('Failed to get response from ChatGPT: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error calling ChatGPT: $e');
      return {
        'text': 'Sorry, I encountered an error. Please try again. If the issue persists, the AI service may be temporarily unavailable.',
        'action': null,
        'actionData': null,
      };
    }
  }
  
  /// Get a quick answer for common questions using ChatGPT
  Future<String> getQuickAnswer(String question) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful assistant for a blockchain charity donation app. Answer in 1-2 sentences.'
            },
            {
              'role': 'user',
              'content': question,
            }
          ],
          'max_tokens': 100,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices'][0]['message']['content'] as String).trim();
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting quick answer: $e');
      return 'Sorry, I couldn\'t answer that right now.';
    }
  }
}
