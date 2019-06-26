//
//  ViewController.swift
//  IntroducingCombine
//
//  Created by Travis Smith on 6/24/19.
//  Copyright © 2019 Travis Smith. All rights reserved.
//

import UIKit
import Combine

class ViewController: UIViewController {

    @IBOutlet weak var usernameIsValidView: UIView!
    @IBOutlet weak var passwordHasSixCharactersView: UIView!
    @IBOutlet weak var passwordHasUpperLowerNumbersView: UIView!
    @IBOutlet weak var passwordsMatchView: UIView!
    @IBOutlet weak var createAccountButton: UIButton!
    
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var passwordConfirmed: String = ""
    
    @IBAction func usernameChanged(_ sender: UITextField) {
        username = sender.text ?? ""
    }
    
    @IBAction func passwordChanged(_ sender: UITextField) {
        password = sender.text ?? ""
    }
    
    @IBAction func passwordConfirmedChanged(_ sender: UITextField) {
        passwordConfirmed = sender.text ?? ""
    }
    
    var passwordHasSixCharacters: AnyPublisher<Bool, Never> {
        return $password
            .map { $0.count >= 6 }
            .eraseToAnyPublisher()
    }
    
    var passwordHasValidCharacters: AnyPublisher<Bool, Never> {
        return $password
            .map { $0.containsCharacterInSet(.uppercaseLetters) &&
                $0.containsCharacterInSet(.lowercaseLetters) &&
                $0.containsCharacterInSet(.decimalDigits) }
            .eraseToAnyPublisher()
    }
    
    var passwordsAreMatching: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest($password, $passwordConfirmed) { password, passwordConfirmed in
            return password == passwordConfirmed
        }
            .eraseToAnyPublisher()
    }
    
    var usernameIsValidSubjectStream: AnyCancellable?
    lazy var usernameIsValidSubject: PassthroughSubject<Bool, Never> = {
        let subject = PassthroughSubject<Bool, Never>()
        usernameIsValidSubjectStream = $username
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .removeDuplicates()
            .flatMap { username in
                return Publishers.Future { promise in
                    self.usernameIsValidView.backgroundColor = .yellow
                    self.usernameAvailable(username) { (available) in
                        promise(.success(available))
                    }
                }
            }.subscribe(subject)
        return subject
    }()
    
    var allCredentialsSatisfied: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest4(usernameIsValidSubject,
                                         passwordHasSixCharacters,
                                         passwordHasValidCharacters,
                                         passwordsAreMatching
        ) { $0 && $1 && $2 && $3 }
            .eraseToAnyPublisher()
    }
    
    var usernameIsValidStream: AnyCancellable?
    var passwordLengthStream: AnyCancellable?
    var passwordValidCharactersStream: AnyCancellable?
    var passwordsMatchStream: AnyCancellable?
    var createAccountEnabledStream: AnyCancellable?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        usernameIsValidStream = usernameIsValidSubject
            .map { [weak self] in self?.colorForState(isValid: $0) }
            .assign(to: \.backgroundColor, on: usernameIsValidView)
        
        passwordLengthStream = passwordHasSixCharacters
            .map { [weak self] in self?.colorForState(isValid: $0) }
            .assign(to: \.backgroundColor, on: passwordHasSixCharactersView)
        
        passwordValidCharactersStream = passwordHasValidCharacters
            .map { [weak self] in self?.colorForState(isValid: $0) }
            .assign(to: \.backgroundColor, on: passwordHasUpperLowerNumbersView)
        
        passwordsMatchStream = passwordsAreMatching
            .map { [weak self] in self?.colorForState(isValid: $0) }
            .assign(to: \.backgroundColor, on: passwordsMatchView)
        
        createAccountEnabledStream = allCredentialsSatisfied
            .assign(to: \.isEnabled, on: createAccountButton)
    }
    
    private func colorForState(isValid: Bool) -> UIColor {
        return isValid ? .green : .red
    }
    
    private func usernameAvailable(_ username: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
            // We just randomly decide if the username is valid after 1 second
            completion(Bool.random())
        }
    }
}

extension String {
    func containsCharacterInSet(_ characterSet: CharacterSet) -> Bool {
        return unicodeScalars.contains { characterSet.contains($0) }
    }
}
