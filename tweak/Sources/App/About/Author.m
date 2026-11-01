#import "Author.h"

// Base64 of the JPEG, in pieces: one literal that long is unkind to every editor and to the compiler's limits.
static NSString *avatarBase64(void) {
    return [@[
    @"/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBAUEBAYFBQUGBgYHCQ4JCQgICRINDQoOFRIWFhUS"
    @"FBQXGiEcFxgfGRQUHScdHyIjJSUlFhwpLCgkKyEkJST/2wBDAQYGBgkICREJCREkGBQYJCQkJCQk"
    @"JCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCT/wAARCABgAGADASIA"
    @"AhEBAxEB/8QAHAAAAgIDAQEAAAAAAAAAAAAABgcFCAIDBAAB/8QAPBAAAQMCBAQEBAQDBwUAAAAA"
    @"AQIDBAURAAYSIQcxQVETImFxFIGRsTJCUqEVM+EWIyQ0Q2LwcnOCwdH/xAAaAQADAQEBAQAAAAAA"
    @"AAAAAAADBAUCAQYA/8QAIhEAAgICAwEAAwEBAAAAAAAAAQIAAwQREiExQRMiQgVR/9oADAMBAAIR"
    @"AxEAPwBrny3AAPrjUpJI3vjt8EdsYKax6DkJJkbJGhpR1lP+6/Lpiu3EapvyZIgvyUMxHdBeUTcl"
    @"tRWpKUgkaUaUAm26lKBV0AdfFaoOUnItTfYSouKQGgoC+nUbH52uB64qlmaqInVZTjDzrxKQXXFO"
    @"atat+R6JANhywll2/wAxrGT+pGTXf8O2wllLYCiq4FlWO9j9f2xzgKaaUkhJS4Aq/Mi32xMQaTUa"
    @"pOT8K0tZJskEXthkULgRWKjFS65FUNXNJNh8sTGtVfZRrod/BFMFyg22yoBbShdIPLf+uPRI6ng5"
    @"rKEIQdRUR15WHvhx5h4LVDL9KVIVCccLabEg8knb6jALU8iV2myW4UqnymHwix1pvyGry9/Lc29D"
    @"jKXK02+K6+icdGqYS8IsqUptptGpC0JDukgeUpSSBe5t67+mHpwqz7KqsB1+RJLzUdTTEhhYUpcd"
    @"KzpS6Fnmm9rpN7A3B8pvX12I7BUSW1NqUnRpWncAEG9u1x98b6fU0x5iX1KcYWmxHhGxSkbi45KB"
    @"HMHmMF3tSB9i5XRBPyXDbSf4i2gXF3UD1HmGGjTANBtbmfsMV24b8S4mcJ8OHNAi1VSwoNnZL1jd"
    @"RR19bHe3fFiaWQWzbufsMKaI6MKTsQW8LGBa2O2BLMmYM05YzlSoMsU1+iz5KGkPtMqSpaVK07kq"
    @"NlJJHofng4Ldxbl8sWkvDDYkxqtewN4kusR8h15T7SnkfBLSWkLKFOE2ASCNwSSMVOyfllNXnLdL"
    @"SvD8QobQTsD1JPW2DbjLxQr82uVfK6UMtQfG8FQH94FpT+FQvsCdje1xtbG3KVDkRo8P4dJUhlAD"
    @"iUjc33KvrhW+0HuO4lPfccuQ8sUOjQGkMRWlrSkAuLAJUe+D1pSNCdIAA5WwKZbgOojJJsbi4xPK"
    @"ToRa5GITMSdmemCAAASZjsJljS4kFJ2NxcHEPnPKsaZTgjwUvKC0eGhaiASFcgQCU7E8vlidpOzY"
    @"AJJOJF65Frm2Doo47iNljK+h5EHxH4Ix5+W1vxB49VY1OlxJI1gD8CQbmwAAF+1+uKyvxn6c46p9"
    @"lYcQdCkHoPXvi/05PkdsL9hin/FWmwoOYZb0a1tR1dUkH0P/ADlglFhDcYHKqBXmPZlwdqTs3P1H"
    @"fShKVtr0LskErSbiw/ff2xdukgBsgDqfsMUQ4VzjDz9THIzTWlElkjWq2kBYvy6kEi+LqTpgNB1s"
    @"rUkuOpSACpJUdQAFxva435eUHlg1nsRXyLDOVcRU8lMynFJLkCbGlNqPMWdSFAe4J+mGQ1MjyJEp"
    @"ph5K3IrvhOgc21WCgD8iD88ISBRMy5pynLfhxRIipSShtvdTik9B3PS2GM/FrFEqFRYizYzOuQpa"
    @"/Aj7KUeV773AsPljq5AqGzOGg2HURfG/h4zlzP8AFnRnVrjVp9ToaKf5S7i6Qeo3uOwxIUusGlvE"
    @"oc0p9OuBXihnXMlerL0aoTpCmqfMdRHbCQkNlJKdQsL3O/1wFKq9QQd5jyv+o3++CMA4hKXNRlpM"
    @"u8QYra0MuuIGqwG/fBPIzREWrZ0WIvzxTyJmWa0rzK1gb3BscTq+I0lMNMZCH1vA81rsB9zhNsY/"
    @"JUTOT7Lf0LM7boSWlpI9SMECaiqU2bbDvih6M611Dl257kf/ALQ/+4n6PxezdTnEFvMlTUlP+mrS"
    @"pB9xbHRQ4HsE+TUx2B3LjvhSm1pKuYxU3jbSV0/M7/m0iwWkHa4PMY6YHGbPC0rU1md06QSBKitL"
    @"SfQmwIwI5lzvWuJE2F/GJMGOpKSnxwz4Y/8ALTzxyqoq+5nItBr0R7Jbgky5Iz1FLDKltIBDh2AQ"
    @"kkDVfpvYd8XJfbbhUB27T7iG1FRZjg3cGx08xYdzfp8sV34HZdTQqeJLr8RyRU5Z8NvVdxbLarag"
    @"O1yT7YszDbVKiutpVbVqSbi4NwBy+uCs4Y9RNqmrA5DW5XfLnEGrqZpxl5nEaMUMlTMaIpSlpG5S"
    @"FXABINvkO2D2pTn2orlSq9XjUYvqK1pAQ6hB7Ba0gqOw6cyemEnIksQYy0zaRJprttSEF9pxOok+"
    @"VGhRJty6YHMy5jqOZJRenvOOJ5JSpXIdPQD0GCriF+z0IB8oKdemas+KhTa/WXIM1M9tUj4hL6Uh"
    @"OsLSCrYbCywobemAR1BSrfBdSKWzU6tFivKVHS6oth1o+ZJINuexF7bHEg/wzqRfcUmXTltoubva"
    @"2yR8gcfOBWdbhqFa4clEAEMqccQhAKlOKCEpA3JJtbBfmjJ9RyfJptVl0N6HDdIADoKkO2G41HrY"
    @"8tvYYn8jZTKMyQ51TQx8PEWFaWgdIPc354s1mei0XOmSV0SQUOsyWipJG5acH4VJ9R/TAnuAOo3X"
    @"itx2R3uVEqWXKO6DOiVZpDSzfwlrSVJ9O/7YjmFU6AsFC3pKxyCQAn6nEnWeHNaolUkUxbbanY6t"
    @"y4dOpJ3SR7jHyFkGsyVpSTHbB7ErP0AxkedtuMaO9ivRkBU6i7LdJKENIH5Uj798MPK3CSbU8m0m"
    @"seGoyqrM8JlojZEfQs6z6qKduw98EWTOB7cmU29V25CmALq8VIQF7jyhPP59sPhltmE3HQ0yEMtA"
    @"NobbAAbSBYADsAAMDe4ABUmUxWLlrIv8qtUmuGA4xAXTn6awY6lNrI8RJtbfoQRy/wBxwxW6pJZT"
    @"ZE50D0Wd9rYX3EusOZfuuhy247yNL0lLeguaVbAqSoG4v2tjk4d5+ers9NLqrzbjroPhOaEoJUN9"
    @"Nhsbi/0xxMazh+T5M52TW13AfIrpsOU5NL7tCkOtlOkMtupAbHTTpO3tiArjMaOqzbFejqtv4qWQ"
    @"PcdcbCZMr/P5hkuDqhpWhJ+mPvwtEaH8hl5X6nVKWT9cXzXs7nnhr/kho0mmxaozKS5VSll9DiAt"
    @"SLgCxuogHqOQ6YdFVQ2WC8OShf0wp5EmhNghcWKT2S0MNPLEuNmHL0aQL6NOgp6gp2t+2J+amtGV"
    @"f819EqIPQ6hLiTkNpWUsKcClC3/Lgjpg7ao1ezW5HZoVWegNR1BzSh7w0rJ532JI9MBypzDNTDiK"
    @"NUJQZVcoUwVoNjyUEnB1lnP8oSXJFPyfKQlfNpERwcu3bE6z3qXqq7OJMMH+FEaqOCfVanIkTgyh"
    @"tRbslHlGw5XtueeN1MpUelo+HbitMrRsdKdz63xqZzxOlbLy3WISxsrW2NCfc32xJRpiZmlw21HY"
    @"4BYfgnF5rvnMtIKgQb364VfHfOlRy25RodJmLiyHEuPOKbtfTslPP1v9MNxSkN2USEgdT0xWfjbJ"
    @"frHEB5lKRaOy1HbCudz5vurBcYAtsxPMsITo9wJkzahN8epTHpLgKrvSFJWsAnqpQBt88EfD9a28"
    @"2UZ1pRUv4pojfuR/6ONWe50mnVlugUtZZp9IaQyo7hK1lJLq1D8xKgRv6DBlwQysJM6PU1tWixE6"
    @"2lKH5jfQn5Df5DDtr/rsySi7aJoy3uxBPfGpx11f4l2HbkMekzHJj6nFJSjUdkpGyR0A9MYsx3pT"
    @"zbDSSt11QQgdyTh42xcJMbpPLfDA4YZgfpMpVLmxpTMSaq7DzjKkth39Ooi3mA29R64hnqPJpxSz"
    @"SIEmfJTsqU20Skq7IvsAP1cz6DE7kVNdj1B9VaclxmGxpTGdV/NUevqB9yO2M/ie79APYRG/EecY"
    @"j81pp5a21utukC/hbEn1OMYGY6gHRHZXKKnF2SEqF1E9sboLceWfPa/Qk4ladHRS3C81GQ65e4Xa"
    @"5Ht2xNvpaslWHc9FRmFkHE9SZpuW62gJemyUp23TfUR72/ribZ8OA2XHlpGnmo7YgkZqkpQQWzqH"
    @"IAg44ER5uaVvNTJDkWnoQS6pBt9O5woEJP7TT2EiEEaof2mkqjRZK2kJBcS4lsEL0kD8wItcj3xX"
    @"PO1Wde4hVSe4m6zPUq1uQSQPsnFjojjCRC/h7xXOQlTKkoUHEoVpSpQWVcrBKbAew74UfEfgvmVr"
    @"OD1Sy5GE6l1AGQPHeQgsOEnW2STc77g9iO2G6tDcmZOyBF5mBmTUMyT4qYRlPSJgfR4Iu64lQvuf"
    @"02t2w6KDVX6BlmnUSOlmMuMwlLywNalOcyR0+eIuh5blUmNaoMMIqyUBt1TR12QOSdXe3P2HbHT4"
    @"CkhKlfiULfucXcXDrKh7BuSbLWBIWf/Z"
    ] componentsJoinedByString:@""];
}

UIImage *SGAuthorAvatar(void) {
    static UIImage *avatar;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSData *data = [[NSData alloc] initWithBase64EncodedString:avatarBase64() options:0];
        avatar = data.length ? [UIImage imageWithData:data] : nil;
    });
    return avatar;
}
