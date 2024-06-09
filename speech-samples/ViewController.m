//
// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE.md file in the project root for full license information.
//

#import "ViewController.h"
#import "AudioRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import <MicrosoftCognitiveServicesSpeech/SPXSpeechApi.h>
#import <Foundation/Foundation.h>

@interface ViewController () {
    NSString *speechKey;
    NSString *serviceRegion;
    NSString *pronunciationAssessmentReferenceText;
    AudioRecorder *recorder;
}

@property (strong, nonatomic) IBOutlet UILabel *recognitionResultLabel;
@property (strong, nonatomic) IBOutlet UILabel *messageLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    speechKey = @"xxxxxxxxxx";
    serviceRegion = @"xxxxx";
    pronunciationAssessmentReferenceText = @"Hello world.";

    // 创建新的UILabel
    self.messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageLabel.textAlignment = NSTextAlignmentCenter;
    self.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.accessibilityIdentifier = @"message_label";
    [self.messageLabel setText:@"Hello, World!"];
      
    // 添加UILabel到父视图
    [self.view addSubview:self.messageLabel];
      
    // 创建约束
    [self.messageLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [self.messageLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;
    [self.messageLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.messageLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;

    self.recognitionResultLabel = [[UILabel alloc] initWithFrame:CGRectMake(50.0, 500.0, 300.0, 300.0)];
    self.recognitionResultLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.recognitionResultLabel.numberOfLines = 0;
    self.recognitionResultLabel.accessibilityIdentifier = @"result_label";
    [self.recognitionResultLabel setText:@"Press a button!"];

    [self.view addSubview:self.recognitionResultLabel];
    // Start keyword recognition
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [self recognizeKeywordFromFile];
    });
}



/*
 * Performs speech recognition on audio data from the default microphone.
 */
- (void)recognizeFromMicrophone {
    SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:speechKey region:serviceRegion];
    speechConfig.speechRecognitionLanguage=@"zh-CN";
    speechConfig.speechSynthesisLanguage=@"zh-CN";
    if (!speechConfig) {
        NSLog(@"Could not load speech config");
        [self updateRecognitionErrorText:(@"Speech Config Error")];
        return;
    }

    [self synthesisToSpeaker:(@"我在听请讲！")];
    [self updateRecognitionResultText:(@"我在听请讲！")];
    NSArray *languages = @[@"en-US", @"zh-CN"];
    SPXAutoDetectSourceLanguageConfiguration *autoDetectConfig = [[SPXAutoDetectSourceLanguageConfiguration alloc] init:languages];
      
    
    int noMatchCount = 0;
      
    while (noMatchCount < 2) {
        [self updateRecognitionStatusText:(@"Listening...")];
        SPXSpeechRecognizer* speechRecognizer = [[SPXSpeechRecognizer alloc]
                                                 init:speechConfig];
            //initWithSpeechConfiguration:speechConfig
            //autoDetectSourceLanguageConfiguration:autoDetectConfig];
        
        if (!speechRecognizer) {
            NSLog(@"Could not create speech recognizer");
            [self updateRecognitionErrorText:(@"Speech Recognition Error")];
            return;
        }
        
        SPXSpeechRecognitionResult *speechResult = [speechRecognizer recognizeOnce];
        if (SPXResultReason_Canceled == speechResult.reason) {
            SPXCancellationDetails *details = [[SPXCancellationDetails alloc] initFromCanceledRecognitionResult:speechResult];
            NSLog(@"Speech recognition was canceled: %@. Did you pass the correct key/region combination?", details.errorDetails);
            [self updateRecognitionErrorText:([NSString stringWithFormat:@"Canceled: %@", details.errorDetails ])];
        } else if (SPXResultReason_RecognizedSpeech == speechResult.reason) {
            NSLog(@"Speech recognition result received: %@", speechResult.text);
            [self updateRecognitionResultText:(speechResult.text)];
            [self updateRecognitionStatusText:(@"Recognized!")];
            __block NSString *resultContent = nil;
            __block NSError *blockError = nil;
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            [self generateTextWithPrompt:speechResult.text completion:^(NSString *content, NSError *error) {
                NSLog(@"generateTextWithPrompt => content: %@, error: %@",content, error);
                if (error) {
                    blockError = error;
                    [self synthesisToSpeaker:(@"大模型出错了，请重启后再试一下")];
                    [self updateRecognitionErrorText:(@"AI LLM generateText error!")];
                } else {
                    resultContent = content;
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            // 在这里处理 resultContent 的个别句子
                            [self updateRecognitionResultText:(content)];
                        });
                    [self synthesisToSpeaker:(content)];
                }
                dispatch_semaphore_signal(semaphore);
                
            }];
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
        } else if (SPXResultReason_NoMatch == speechResult.reason) {
            NSLog(@"No match found.");
            [self updateRecognitionResultText:(@"我没听清，您还在说话吗？")];
            [self updateRecognitionStatusText:(@"Cannot recognize!")];
            [self synthesisToSpeaker:(@"我没听清，您还在说话吗？")];
            noMatchCount++;
            
        } else {
            NSLog(@"There was an error.");
            [self updateRecognitionErrorText:(@"Speech Recognition Error")];
        }
    }
    [self updateRecognitionResultText:(@"我先退下了，您可以再次唤醒我说'Computer'")];
    [self updateRecognitionStatusText:(@"Quit!")];
    
    [self synthesisToSpeaker:(@"我先退下了，您可以再次唤醒我说'Computer'")];
    
}
- (void)synthesisToSpeaker:(NSString *)inputText{
    SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:speechKey region:serviceRegion];
    if (!speechConfig) {
        NSLog(@"Could not load speech config");
        [self updateRecognitionErrorText:(@"Speech Config Error")];
        return;
    }
    // Sets the synthesis language.
    // The full list of supported language can be found here:
    // https://docs.microsoft.com/azure/cognitive-services/speech-service/language-support#text-to-speech
    speechConfig.speechSynthesisLanguage = @"zh-CN";
    
    // Sets the voice name
    // e.g. "en-GB-RyanNeural".
    // The full list of supported voices can be found here:
    // https://aka.ms/csspeech/voicenames
    // And, you can try getVoices method to get all available voices.
    speechConfig.speechSynthesisVoiceName = @"zh-CN-XiaoxiaoMultilingualNeural";
    // Sets the synthesis output format.
    // The full list of supported format can be found here:
    // https://docs.microsoft.com/azure/cognitive-services/speech-service/rest-text-to-speech#audio-outputs
    [speechConfig setSpeechSynthesisOutputFormat:SPXSpeechSynthesisOutputFormat_Riff16Khz16BitMonoPcm];
    // If you are using Custom Voice (https://aka.ms/customvoice),
    // uncomment the following line to set the endpoint id of your Custom Voice model.
    // speechConfig.EndpointId = @"YourEndpointId";
    NSLog(@"Synthesizing...");
    [self updateRecognitionStatusText:(@"Speaking...")];

    SPXSpeechSynthesizer *synthesizer = [[SPXSpeechSynthesizer alloc] init:speechConfig];
    if (!synthesizer) {
        NSLog(@"Could not create speech synthesizer");
        [self updateRecognitionErrorText:(@"Speech Synthesis Error")];
        return;
    }

    //SPXSpeechSynthesisResult *speechResult = [synthesizer speakText:inputText];
    NSString *voiceName = @"zh-CN-XiaoxiaoMultilingualNeural"; // Replace with the desired voice name
    NSString *resultString = [inputText stringByReplacingOccurrencesOfString:@"*" withString:@""];
    NSString *ssmlText = [NSString stringWithFormat:
                          @"<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'>"
                           "<voice name='%@'>"
                            "<prosody rate='+14%%'>%@</prosody>"
                           "</voice>"
                          "</speak>", voiceName, resultString];
      
    // Perform speech synthesis with SSML
    SPXSpeechSynthesisResult *speechResult = [synthesizer speakSsml:ssmlText];
    // Checks result.
    if (SPXResultReason_Canceled == speechResult.reason) {
        SPXSpeechSynthesisCancellationDetails *details = [[SPXSpeechSynthesisCancellationDetails alloc] initFromCanceledSynthesisResult:speechResult];
        NSLog(@"Speech synthesis was canceled: %@. Did you pass the correct key/region combination?", details.errorDetails);
        [self updateRecognitionErrorText:([NSString stringWithFormat:@"Canceled: %@", details.errorDetails])];
    } else if (SPXResultReason_SynthesizingAudioCompleted == speechResult.reason) {
        NSLog(@"Speech synthesis was completed");
        [self updateRecognitionStatusText:@"Speech speaking was completed."];
    } else {
        NSLog(@"Speech synthesis error.");
        [self updateRecognitionErrorText:(@"Speech synthesis error.")];
    }
}

/*
 * Performs keyword recognition from a wav file using kws.table keyword model
 */
- (void)recognizeKeywordFromFile {
    NSBundle *mainBundle = [NSBundle mainBundle];
    //NSString *kwsWeatherFile = [mainBundle pathForResource: @"kws_whatstheweatherlike" ofType:@"wav"];
    //NSLog(@"kws_weatherFile path: %@", kwsWeatherFile);
    /*
    if (!kwsWeatherFile) {
        NSLog(@"Cannot find audio file!");
        [self updateRecognitionErrorText:(@"Cannot find audio file")];
        return;
    }
    */
    while(true)
    {
    //SPXAudioConfiguration* audioFileInput = [[SPXAudioConfiguration alloc] initWithWavFileInput:kwsWeatherFile];
    SPXAudioConfiguration* audioFileInput = [[SPXAudioConfiguration alloc] init];

    if (!audioFileInput) {
        NSLog(@"Loading audio file failed!");
        [self updateRecognitionErrorText:(@"Audio Error")];
        return;
    }

    NSString *keywordModelFile = [mainBundle pathForResource: @"kws" ofType:@"table"];
    NSLog(@"keyword model file path: %@", keywordModelFile);
    if (!keywordModelFile) {
        NSLog(@"Cannot find keyword model file!");
        [self updateRecognitionErrorText:(@"Cannot find keyword model file")];
        return;
    }

    SPXKeywordRecognitionModel* keywordRecognitionModel = [[SPXKeywordRecognitionModel alloc] initFromFile:keywordModelFile];

    SPXKeywordRecognizer* keywordRecognizer = [[SPXKeywordRecognizer alloc] init:audioFileInput];
    if (!keywordRecognizer) {
        NSLog(@"Could not create keyword recognizer");
        [self updateRecognitionResultText:(@"Keyword Recognition Error")];
        return;
    }
    [self updateRecognitionResultText:(@"您好，请叫我Computer。")];
    [self synthesisToSpeaker:(@"您好，您可以唤醒我说Computer。")];
    
        

        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block SPXKeywordRecognitionResult * keywordResult;
        [keywordRecognizer recognizeOnceAsync: ^ (SPXKeywordRecognitionResult *srresult) {
            keywordResult = srresult;
            dispatch_semaphore_signal(semaphore);
        }keywordModel:keywordRecognitionModel];
        
        [self updateRecognitionStatusText:(@"Waiting for wakeup...")];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        if (SPXResultReason_Canceled == keywordResult.reason) {
            SPXCancellationDetails *details = [[SPXCancellationDetails alloc] initFromCanceledRecognitionResult:keywordResult];
            NSLog(@"Keyword recognition was canceled: %@.", details.errorDetails);
            [self updateRecognitionErrorText:([NSString stringWithFormat:@"Canceled: %@", details.errorDetails ])];
        } else if (SPXResultReason_RecognizedKeyword == keywordResult.reason) {
            NSLog(@"Keyword recognition result received: %@", keywordResult.text);
            [self updateRecognitionResultText:(@"Hello! I'm back...")];
            [self updateRecognitionStatusText:(keywordResult.text)];
        } else {
            NSLog(@"There was an error.");
            [self updateRecognitionErrorText:(@"Keyword Recognition Error")];
        }
        [self recognizeFromMicrophone];
    }
}



- (void)updateRecognitionResultText:(NSString *) resultText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.messageLabel.textColor = UIColor.whiteColor;
        self.messageLabel.text=resultText;
        //self.recognitionResultLabel.textColor = UIColor.whiteColor;
        //self.recognitionResultLabel.text = resultText;
    });
}

- (void)updateRecognitionErrorText:(NSString *) errorText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recognitionResultLabel.textColor = UIColor.redColor;
        self.recognitionResultLabel.text = errorText;
    });
}

- (void)updateRecognitionStatusText:(NSString *) statusText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recognitionResultLabel.textColor = UIColor.yellowColor;
        self.recognitionResultLabel.text = statusText;
    });
}
- (void)getLLMResponseWithMessages:(NSArray *)messages tools:(NSArray *)tools completion:(void (^)(NSDictionary *response, NSError *error))completion {
    __block NSInteger i = 20;
    __block NSArray *messagesAI = [messages subarrayWithRange:NSMakeRange(MAX((NSInteger)messages.count - i, 0), MIN(i, messages.count))];
      
    while (messagesAI.count > 0 && [messagesAI.firstObject[@"role"] isEqualToString:@"tool"]) {
        i++;
        messagesAI = [messages subarrayWithRange:NSMakeRange(MAX((NSInteger)messages.count - i, 0), MIN(i, messages.count))];
    }
      
    NSDictionary *sysmesg = @{@"role": @"system",@"content": @"你是AI助手，会尽力帮助人解决问题。"};
    NSMutableArray *finalMessages = [NSMutableArray arrayWithObject:sysmesg];
    [finalMessages addObjectsFromArray:messagesAI];
      
    NSDictionary *parameters = @{
        //@"engine": [self getChatDeployment],
        @"messages": finalMessages,
        @"temperature": @0.6,
        @"max_tokens": @500,
        //@"tools": tools,
        //@"tool_choice": @"auto",
        @"stream": @NO
    };
      
    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&error];
      
    if (error) {
        completion(nil, error);
        return;
    }
      
    NSURL *url = [NSURL URLWithString:@"https://xxxx.openai.azure.com/openai/deployments/gpt-4o/chat/completions?api-version=2024-02-15-preview"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"xxxx" forHTTPHeaderField:@"api-key"];
    [request setHTTPBody:postData];
      
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
        } else {
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                completion(nil, error);
            } else {
                NSDictionary *choice = jsonResponse[@"choices"][0];
                completion(choice[@"message"], nil);
            }
        }
    }];
      
    [dataTask resume];
}
  
- (NSString *)getChatDeployment {
    // Implement your method to get chat deployment
    return @"gpt-4o";
}
- (void)runConversationWithMessages:(NSMutableArray *)messages tools:(NSArray *)tools completion:(void (^)(NSDictionary *response, NSError *error))completion {
    [self getLLMResponseWithMessages:messages tools:tools completion:^(NSDictionary *responseMessage, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
          
        if (responseMessage[@"tool_calls"]) {
            NSArray *toolCalls = responseMessage[@"tool_calls"];
            [messages addObject:responseMessage]; // extend conversation with assistant's reply
              
            for (NSDictionary *toolCall in toolCalls) {
                NSLog(@"⏳Call internal function...");
                NSString *functionName = toolCall[@"function"][@"name"];
                NSLog(@"⏳Call %@...", functionName);
                  
                NSDictionary *functionArgs = [NSJSONSerialization JSONObjectWithData:[toolCall[@"function"][@"arguments"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                NSLog(@"⏳Call params: %@", functionArgs);
                  
                // Call the function dynamically
                SEL selector = NSSelectorFromString(functionName);
                id functionResponse = [self performSelector:selector withObject:functionArgs];
                  
                NSLog(@"⏳Call internal function done!");
                NSLog(@"执行结果：%@", functionResponse);
                NSLog(@"===================================");
                  
                [messages addObject:@{
                    @"tool_call_id": toolCall[@"id"],
                    @"role": @"tool",
                    @"name": functionName,
                    @"content": functionResponse
                }];
            }
              
            // Recursively call runConversation
            [self runConversationWithMessages:messages tools:tools completion:completion];
        } else {
            completion(responseMessage, nil);
        }
    }];
}

  
// Example function to be called
- (NSString *)exampleFunctionWithArguments:(NSDictionary *)args {
    // Implement your function logic here
    return @"Function response";
}

  
NSMutableArray *messages;
  
- (instancetype)init {
    self = [super init];
    if (self) {
        messages = [NSMutableArray array];
    }
    return self;
}
- (void)generateTextWithPrompt:(NSString *)prompt completion:(void (^)(NSString *content, NSError *error))completion {
    [messages addObject:@{@"role": @"user", @"content": prompt}];
    NSArray *tools = [self getTools];
      
    [self runConversationWithMessages:messages tools:tools completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            completion(nil, error);
        } else {
            completion(response[@"content"], nil);
            [messages addObject:@{@"role": @"assistant", @"content": response[@"content"]}];
        }
    }];
}
- (NSArray *)getTools {
    // Implement your method to get tools
    return @[];
}

@end

