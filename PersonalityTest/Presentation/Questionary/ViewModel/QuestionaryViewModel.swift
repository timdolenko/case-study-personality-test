import Foundation

public class QuestionaryViewModel {
    
    public enum State {
        case initial
        case loadingQuestions
        case didFailToLoadQuestions(Error)
        case didDisplay(Question)
        case didSelectAnswer(Question, Answer)
        case savingResults
        case didSaveResults
        case didFailToSaveResults(Error)
        
        public var answer: Answer? {
            guard case let .didSelectAnswer(_,value) = self else { return nil }
            return value
        }
        
        public var question: Question? {
            switch self {
            case let .didDisplay(question):
                return question
            case let .didSelectAnswer(question, _):
                return question
            default:
                return nil
            }
        }
        
        public var title: String {
            switch self {
            case .initial,
                 .loadingQuestions:
                return "Welcome"
            case .didSaveResults:
                return "Thank you!"
            default:
                return "Personality Test"
            }
        }
    }
    
    public enum Event {
        case didRequestQuestions
        case didLoadQuestions
        case didFailToLoadQuestions(Error)
        case didSelectAnswer(Question, Answer)
        case didTapNext
        case didSaveResults
        case didFailToSaveResults(Error)
    }
    
    public var state: Observable<State> = Observable(.initial)
    
    private var questionQueue: [Question] = []
    private var currentQuestionIndex: Int = -1
    private var currentQuestion: Question? {
        return questionQueue[safe: currentQuestionIndex]
    }
    private var answers: [Question:Answer] = [:]
    private var currentAnswer: Answer? {
        guard let currentQuestion = currentQuestion else { return nil }
        return answers[currentQuestion]
    }
    
    private var questions: [Question]?
    private var categories: [String]?
    
    private var interactor: QuestionsInteractorProtocol
    
    init(interactor: QuestionsInteractorProtocol) {
        self.interactor = interactor
    }
    
    func send(_ event: Event) {
        state.value = reduce(state.value, event)
        handle(event)
    }
    
    private func requestQuestions() {
        interactor.fetchQuestions { [weak self] (result) in
            guard let `self` = self else { return }
            
            switch result {
            case let .success(response):
                self.setupQueue(with: response)
            case let .failure(error):
                self.send(.didFailToLoadQuestions(error))
            }
        }
    }
    
    private func saveAnswers() {
        interactor.saveAnswers(answers: answers) { [weak self] (result) in
            guard let `self` = self else { return }
            
            switch result {
            case .success:
                self.send(.didSaveResults)
            case let .failure(error):
                self.send(.didFailToSaveResults(error))
            }
        }
    }
    
    private func setupQueue(with response: QuestionList) {
        questions = response.questions
        categories = response.categories
        
        currentQuestionIndex = -1
        questionQueue = response.categories
            .map { category in
                response.questions.filter { $0.category == category }
            }
            .flatMap { $0 }
        
        send(.didLoadQuestions)
    }
    
    private func requestNextQuestion() -> Question? {
        
        insertConditionQuestionIfNeeded()
        
        currentQuestionIndex += 1
        
        return questionQueue[safe: currentQuestionIndex]
    }
    
    private func insertConditionQuestionIfNeeded() {
        guard let current = currentQuestion else { return }
        guard let condition = current.answerDescription.condition else { return }
        guard let answer = currentAnswer else { return }
        guard let question = condition.nextQuestion(for: answer) else { return }
        
        questionQueue.insert(question, at: currentQuestionIndex + 1)
    }
    
    private func handle(_ event: Event) {
        
        switch event {
        case .didRequestQuestions:
            requestQuestions()
        case .didLoadQuestions, .didTapNext:
            handleSavingResultsIfNeeded()
        default:
            break
        }
    }
    
    private func handleSavingResultsIfNeeded() {
        guard case .savingResults = state.value else { return }
        saveAnswers()
    }
    
    private func reduce(_ state: State, _ event: Event) -> State {
        switch event {
        case .didRequestQuestions:
            return .loadingQuestions
        case .didLoadQuestions, .didTapNext:
            
            // Can only tap next if answer is selected
            if case .didTapNext = event {
                guard let question = state.question, let _ = answers[question] else {
                    return state
                }
            }
            
            if let nextQuestion = requestNextQuestion() {
                return .didDisplay(nextQuestion)
            } else {
                return .savingResults
            }
        
        case .didSaveResults:
            return .didSaveResults
            
        case let .didFailToSaveResults(error):
            return .didFailToSaveResults(error)
            
        case let .didSelectAnswer(question, answer):
            
            let verificationResult = question.answerDescription.verifyAnswer(answer)
            
            switch verificationResult {
            case let .success(answer):
                answers[question] = answer
                return .didSelectAnswer(question, answer)
            case .failure:
                return .didDisplay(question)
            }
            
        case let .didFailToLoadQuestions(error):
            return .didFailToLoadQuestions(error)
        }
    }
}
