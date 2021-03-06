\name{print.BBest}
\alias{print.BBest}
\title{
Print a BBest class model.
}
\description{
\code{print.BBest} is the BBest specific method fot the generic function print which prints objects returned by modelling functions.
}

\usage{
\method{print}{BBest}(x, ...)
}

\arguments{
\item{x}{ a BBest class model.}
\item{...}{ for extra arguments.}
}

\value{
Prints a BBest object.
}

\author{
J. Najera-Zuloaga

D.-J. Lee

I. Arostegui
}
\references{
Arostegui I., Nunez-Anton V. & Quintana J. M. (2006): Analysis of short-form-36 (SF-36): The beta-binomial distribution approach, \emph{Statistics in Medicine}, \bold{26}, 1318-1342
}

\seealso{
\code{\link{BBest}}
}

\examples{
set.seed(9)
# Simulate a binomial distribution
y <- rBB(100,10,0.5,2)

# Apply the model
model <- BBest(y,10)
print(model)   # or just model

}
