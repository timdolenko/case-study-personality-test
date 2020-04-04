//
//  Question.swift
//  PersonalityTest
//
//  Created by Tymofii Dolenko on 04.04.2020.
//

import Foundation

enum QuestionTypeString: String, Codable {
    case singleChoice = "single_choice"
    case singleChoiceConditional = "single_choice_conditional"
    case numberRange = "number_range"
}

struct QuestionType {
    
    typealias Options = [String]
    
    struct NumberRange: Decodable {
        var from: Int
        var to: Int
    }
    
    struct Condition: Decodable {
        
        enum Predicate: Decodable {
            
            enum CodingKeys: String, CodingKey {
                case exactEquals
            }
            
            case exactEquals([String])
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                let predicate = try container.decode([String].self, forKey: .exactEquals)
                self = .exactEquals(predicate)
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case predicate
            case ifPositive = "if_positive"
            case ifNegative = "if_negative"
        }
        
        var predicate: Predicate
        var ifPositive: Question?
        var ifNegative: Question?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            predicate = try container.decode(Predicate.self, forKey: .predicate)
            ifPositive = try? container.decode(Question.self, forKey: .ifPositive)
            ifNegative = try? container.decode(Question.self, forKey: .ifNegative)
        }
    }
    
    enum AnswerType {
        case singleChoice(options: [String])
        case numberRange(range: NumberRange)
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case options
        case range
        case condition
    }
    
    var typeString: QuestionTypeString
    var type: AnswerType
    var condition: QuestionType.Condition?
}

extension QuestionType: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        typeString = try container.decode(QuestionTypeString.self, forKey: .type)
        
        switch typeString {
        case .singleChoice, .singleChoiceConditional:
            
            let options = try container.decode(Options.self, forKey: .options)
        
            type = .singleChoice(options: options)
            
        case .numberRange:
            
            let range = try container.decode(NumberRange.self, forKey: .range)
            
            type = .numberRange(range: range)
        }
        
        condition = try? container.decode(Condition.self, forKey: .condition)
    }
}

class Question: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case question
        case category
        case questionType = "question_type"
    }
    
    var title: String
    var category: String
    var type: QuestionType
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decode(String.self, forKey: .question)
        category = try container.decode(String.self, forKey: .category)
        type = try container.decode(QuestionType.self, forKey: .questionType)
    }
}